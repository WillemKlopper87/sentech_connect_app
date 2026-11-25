import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/coverage/data/pending_lead_keys.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/domain/repositories/coverage_repository.dart';

enum NotifyStatus { idle, submitting, done, failed }

/// The contact, the address and the coordinates are never part of this state:
/// they pass through [NotifyCubit.submit] and are gone when it returns.
class NotifyState extends Equatable {
  const NotifyState({this.status = NotifyStatus.idle, this.failure, this.outcomeUnknown = false});

  final NotifyStatus status;
  final Failure? failure;

  /// A sign-up was sent and the app does not know whether it arrived. The next
  /// submit of the same request is a retry of it (same key, so one lead).
  final bool outcomeUnknown;

  /// The consent text changed since the form was shown: the customer must read it and tick again.
  bool get consentOutdated => failure is ConsentVersionOutdatedFailure;

  @override
  List<Object?> get props => [status, failure, outcomeUnknown];
}

/// Joins the waiting list. ONE idempotency key per attempt: a double tap sends
/// one request; a retry of the same request after a lost or unfinished one
/// reuses the key (the platform keeps one lead); a changed request, a new
/// attempt after success, or a final refusal starts a new key (the platform
/// refuses one key for two different requests). Closing the sheet while a
/// request is in flight emits nothing afterwards.
class NotifyCubit extends Cubit<NotifyState> {
  NotifyCubit(this._repository, {String Function()? newKey, PendingLeadKeys? pending, String scope = ''})
    : _newKey = newKey ?? newIdempotencyKey,
      _pending = pending ?? PendingLeadKeys(),
      _scope = scope,
      super(const NotifyState()) {
    // Reopened after a lost response: the same request is the one to retry.
    final earlier = _pending.pendingFor(scope);
    if (earlier != null) {
      _key = earlier.key;
      _fingerprint = earlier.fingerprint;
      emit(const NotifyState(outcomeUnknown: true));
    }
  }

  final CoverageRepository _repository;
  final String Function() _newKey;
  final PendingLeadKeys _pending;
  final String _scope;

  String? _key;
  int? _fingerprint;

  bool get _busy => state.status == NotifyStatus.submitting;

  Future<void> submit(NotifyRequest request) async {
    if (isClosed || _busy) return;
    final fingerprint = Object.hashAll(request.props);
    if (_key == null || _fingerprint != fingerprint) {
      _key = _newKey();
      _fingerprint = fingerprint;
    }
    final key = _key!;
    emit(NotifyState(status: NotifyStatus.submitting, outcomeUnknown: state.outcomeUnknown));
    final result = await _repository.submitLead(request, idempotencyKey: key);
    if (isClosed) return;
    switch (result) {
      case Right():
        _forgetKey();
        emit(const NotifyState(status: NotifyStatus.done));
      case Left(value: final failure):
        // Only an outcome the app cannot know keeps the key: the retry is then the same
        // request. A final answer from the platform (or no request at all) starts afresh.
        final unknown = _outcomeUnknown(failure);
        if (unknown) {
          _pending.put(_scope, fingerprint, key);
        } else {
          _forgetKey();
        }
        emit(NotifyState(status: NotifyStatus.failed, failure: failure, outcomeUnknown: unknown));
    }
  }

  /// Back to the form (after a refusal the customer has read).
  void dismiss() {
    if (isClosed || _busy) return;
    emit(NotifyState(outcomeUnknown: state.outcomeUnknown && _key != null));
  }

  void _forgetKey() {
    _key = null;
    _fingerprint = null;
    _pending.remove(_scope);
  }

  static bool _outcomeUnknown(Failure failure) =>
      failure is NetworkFailure ||
      failure is ServerFailure ||
      failure is IdempotencyInProgressFailure ||
      failure is RateLimitedFailure ||
      failure is HumanVerificationUnavailableFailure;
}
