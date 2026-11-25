import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';

enum StreakStatus { loading, ready, unavailable, error }

enum ClaimStatus { idle, claiming, done, failed }

class StreakCubitState extends Equatable {
  const StreakCubitState({
    this.status = StreakStatus.loading,
    this.streak,
    this.failure,
    this.claimStatus = ClaimStatus.idle,
    this.claim,
    this.claimFailure,
  });

  final StreakStatus status;

  /// The streak as the server last said it (from the read, or from a claim).
  final StreakState? streak;
  final Failure? failure;
  final ClaimStatus claimStatus;

  /// The last successful claim answer. `claim.claimed == false` means today had
  /// already been claimed: shown as "already checked in", never as an error.
  final ClaimResult? claim;
  final Failure? claimFailure;

  bool get claimBlocked => switch (claimFailure) {
    WalletFrozenFailure() || CustomerInactiveFailure() || CreditsPausedFailure() => true,
    _ => false,
  };

  @override
  List<Object?> get props => [status, streak, failure, claimStatus, claim, claimFailure];
}

/// The streak and today's check-in. ONE idempotency key per attempt: a double
/// tap sends one request and a retry after a lost response reuses the key.
/// The cubit never decides what counts as a day: it always asks the server, and
/// a second claim the same Johannesburg day answers `claimed: false`.
class StreakCubit extends Cubit<StreakCubitState> {
  StreakCubit(this._repository, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey,
      super(const StreakCubitState()) {
    load();
  }

  final CreditsRepository _repository;
  final String Function() _newKey;
  String? _key;
  int _generation = 0;

  bool get _busy => state.claimStatus == ClaimStatus.claiming;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    if (!keepVisible || state.streak == null) emit(const StreakCubitState());
    final result = await _repository.streak();
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) {
        if (failure is CreditsNotAvailableFailure) {
          emit(StreakCubitState(status: StreakStatus.unavailable, failure: failure));
        } else if (!(keepVisible && state.streak != null)) {
          emit(StreakCubitState(status: StreakStatus.error, failure: failure));
        }
      },
      (streak) => emit(
        StreakCubitState(
          status: StreakStatus.ready,
          streak: streak,
          claimStatus: state.claimStatus == ClaimStatus.claiming ? ClaimStatus.claiming : ClaimStatus.idle,
          claim: state.claim,
        ),
      ),
    );
  }

  Future<void> refresh() => load(keepVisible: true);

  Future<void> claim() async {
    if (isClosed || _busy || state.streak == null) return;
    _key ??= _newKey();
    emit(StreakCubitState(status: StreakStatus.ready, streak: state.streak, claimStatus: ClaimStatus.claiming));
    final result = await _repository.claimToday(idempotencyKey: _key!);
    if (isClosed) return;
    switch (result) {
      case Right(value: final claim):
        _key = null;
        emit(StreakCubitState(status: StreakStatus.ready, streak: claim.streak, claimStatus: ClaimStatus.done, claim: claim));
      case Left(value: final failure):
        // The outcome is unknown after a lost or unfinished request: keep the
        // key so the retry is the same request. A final answer starts afresh.
        if (!(failure is NetworkFailure ||
            failure is ServerFailure ||
            failure is IdempotencyInProgressFailure ||
            failure is RateLimitedFailure)) {
          _key = null;
        }
        emit(
          StreakCubitState(
            status: StreakStatus.ready,
            streak: state.streak,
            claimStatus: ClaimStatus.failed,
            claimFailure: failure,
          ),
        );
    }
  }
}
