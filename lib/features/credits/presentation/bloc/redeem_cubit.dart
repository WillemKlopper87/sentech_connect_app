import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/credits/data/pending_redeem_keys.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';

enum RedeemStatus { idle, submitting, done, failed }

class RedeemState extends Equatable {
  const RedeemState({this.status = RedeemStatus.idle, this.credits, this.pass, this.failure, this.pendingCredits});

  final RedeemStatus status;

  /// The pack size of the attempt in progress, or of the last result.
  final int? credits;
  final Pass? pass;
  final Failure? failure;

  /// A redeem of this pack has an unknown outcome (a lost response). Until it
  /// resolves, only this pack can be tried again, with the same key.
  final int? pendingCredits;

  /// The server said, in words the customer should read, that nothing can be
  /// redeemed until something outside this screen changes (a frozen wallet, an
  /// inactive account, a pause, or the feature being off). The screen then
  /// disables every pack.
  bool get blocksActions => switch (failure) {
    WalletFrozenFailure() ||
    CustomerInactiveFailure() ||
    CreditsPausedFailure() ||
    CreditsNotAvailableFailure() => true,
    _ => false,
  };

  @override
  List<Object?> get props => [status, credits, pass, failure, pendingCredits];
}

/// Redeems one pack. ONE idempotency key per attempt: a double tap sends one
/// request; a retry of the same pack after a lost or unfinished request reuses
/// the key (the server returns the same pass and never spends twice); a
/// different pack, a new attempt after success, or a final refusal starts a new
/// key (the server refuses one key for two different requests). Closing the
/// page while a request is in flight emits nothing afterwards.
class RedeemCubit extends Cubit<RedeemState> {
  RedeemCubit(this._repository, {String Function()? newKey, PendingRedeemKeys? pending, String scope = ''})
    : _newKey = newKey ?? newIdempotencyKey,
      _pending = pending ?? PendingRedeemKeys(),
      _scope = scope,
      super(const RedeemState()) {
    // Reopened after a lost response: the same pack is the only one to retry.
    final earlier = _pending.pendingFor(scope);
    if (earlier != null) {
      _keyCredits = earlier.credits;
      _key = earlier.key;
      emit(RedeemState(pendingCredits: earlier.credits));
    }
  }

  final CreditsRepository _repository;
  final String Function() _newKey;
  final PendingRedeemKeys _pending;
  final String _scope;

  int? _keyCredits;
  String? _key;

  bool get _busy => state.status == RedeemStatus.submitting;

  Future<void> redeem(int credits) async {
    if (isClosed || _busy) return;
    final unresolved = state.pendingCredits;
    // Another pack while one is unresolved could spend twice: refused.
    if (unresolved != null && unresolved != credits) return;
    if (_key == null || _keyCredits != credits) {
      _keyCredits = credits;
      _key = _newKey();
    }
    final key = _key!;
    emit(RedeemState(status: RedeemStatus.submitting, credits: credits, pendingCredits: unresolved));
    final result = await _repository.redeem(credits: credits, idempotencyKey: key);
    if (isClosed) return;
    switch (result) {
      case Right(value: final pass):
        _forgetKey();
        emit(RedeemState(status: RedeemStatus.done, credits: credits, pass: pass));
      case Left(value: final failure):
        // Only an outcome the app cannot know keeps the key: the retry is then
        // the same request. A final answer from the server starts afresh.
        final unknown = _outcomeUnknown(failure);
        if (unknown) {
          _pending.put(_scope, credits, key);
        } else {
          _forgetKey();
        }
        emit(
          RedeemState(
            status: RedeemStatus.failed,
            credits: credits,
            failure: failure,
            pendingCredits: unknown ? credits : null,
          ),
        );
    }
  }

  /// Back to choosing a pack (after a result or a refusal the customer has read).
  void dismiss() {
    if (isClosed || _busy) return;
    emit(RedeemState(pendingCredits: state.pendingCredits));
  }

  void _forgetKey() {
    _key = null;
    _keyCredits = null;
    _pending.remove(_scope);
  }

  static bool _outcomeUnknown(Failure failure) =>
      failure is NetworkFailure ||
      failure is ServerFailure ||
      failure is IdempotencyInProgressFailure ||
      failure is RateLimitedFailure;
}
