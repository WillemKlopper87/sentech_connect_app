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
  const NotifyState({this.status = NotifyStatus.idle, this.failure, this.outcomeUnknown = false, this.notSent = false, this.retryAt});

  final NotifyStatus status;
  final Failure? failure;

  /// A sign-up was sent and the app does not know whether it arrived. The next submit of the
  /// same request is a retry of it (same key, so one lead).
  final bool outcomeUnknown;

  /// The last attempt was NOT sent or saved (the security check was unavailable, or the rate
  /// limit held it): nothing happened on the platform, trying again is safe.
  final bool notSent;

  /// While set (and in the future) no sign-up is sent: the platform's `Retry-After`.
  final DateTime? retryAt;

  /// The consent text changed since the form was shown: the customer must read it and tick again.
  bool get consentOutdated => failure is ConsentVersionOutdatedFailure;

  @override
  List<Object?> get props => [status, failure, outcomeUnknown, notSent, retryAt];
}

/// Joins the waiting list. ONE idempotency key per attempt: a double tap sends one request; a
/// retry of the same request after a lost or unfinished one reuses the key (the platform keeps
/// one lead); a changed request, a new attempt after success, or a final refusal starts a new
/// key. The key is stored BEFORE the request leaves and removed only on success or a final
/// answer from the platform, even if the sheet was closed meanwhile (so closing mid-request
/// and reopening retries the same request). Backing out of the security check changes nothing.
/// A key the platform says belongs to another request is replaced once, automatically.
class NotifyCubit extends Cubit<NotifyState> {
  NotifyCubit(
    this._repository, {
    String Function()? newKey,
    PendingLeadKeys? pending,
    String scope = '',
    DateTime Function()? now,
  }) : _newKey = newKey ?? newIdempotencyKey,
       _pending = pending ?? PendingLeadKeys(),
       _scope = scope,
       _now = now ?? DateTime.now,
       super(const NotifyState()) {
    // Reopened for the same place after an unsettled attempt: that attempt's key is the one to retry.
    final earlier = _pending.pendingFor(scope);
    if (earlier != null) {
      _key = earlier.key;
      emit(NotifyState(outcomeUnknown: earlier.unknown));
    }
  }

  final CoverageRepository _repository;
  final String Function() _newKey;
  final PendingLeadKeys _pending;
  final String _scope;
  final DateTime Function() _now;

  /// Without a `Retry-After` hint the customer waits this long.
  static const defaultRetryAfter = Duration(seconds: 30);

  /// The clock the rate-limit wait is measured with (the sheet counts down against the same one).
  DateTime now() => _now();

  String? _key;
  int? _fingerprint; // in memory in this cubit only; never stored in the holder
  DateTime? _blockedUntil;
  Failure? _blockFailure;

  bool get _busy => state.status == NotifyStatus.submitting;

  Future<void> submit(NotifyRequest request) async {
    if (isClosed || _busy) return;
    final until = _blockedUntil;
    if (until != null && _now().isBefore(until)) {
      // Held: nothing is sent until the platform's wait is over.
      emit(
        NotifyState(
          status: NotifyStatus.failed,
          failure: _blockFailure ?? const RateLimitedFailure(),
          outcomeUnknown: state.outcomeUnknown,
          notSent: true,
          retryAt: until,
        ),
      );
      return;
    }
    await _attempt(request, canReplaceKey: true);
  }

  Future<void> _attempt(NotifyRequest request, {required bool canReplaceKey}) async {
    final fingerprint = Object.hashAll(request.props);
    final previousKey = _key;
    final previousFingerprint = _fingerprint;
    final previousPending = _pending.pendingFor(_scope);
    if (_key == null || (_fingerprint != null && _fingerprint != fingerprint)) _key = _newKey();
    _fingerprint = fingerprint;
    final key = _key!;
    // Kept from the moment the request is sent: a lost answer or a closed sheet must not lose it.
    _pending.put(_scope, key, unknown: true);
    if (!isClosed) emit(NotifyState(status: NotifyStatus.submitting, outcomeUnknown: state.outcomeUnknown));
    final result = await _repository.submitLead(request, idempotencyKey: key);
    // Bookkeeping runs even when the sheet was closed; only the emits are guarded.
    switch (result) {
      case Right():
        _forgetKey();
        if (!isClosed) emit(const NotifyState(status: NotifyStatus.done));
      case Left(value: final failure):
        if (failure is HumanCheckCancelledFailure) {
          // Nothing was sent: put everything back as it was (an earlier unknown attempt stays unknown).
          _key = previousKey;
          _fingerprint = previousFingerprint;
          if (previousPending == null) {
            _pending.remove(_scope);
          } else {
            _pending.put(_scope, previousPending.key, unknown: previousPending.unknown);
          }
          if (!isClosed) {
            emit(NotifyState(status: NotifyStatus.failed, failure: failure, outcomeUnknown: previousPending?.unknown ?? false));
          }
          return;
        }
        if (canReplaceKey && failure is ValidationFailure && failure.code == 'idempotency_key_reused') {
          _forgetKey();
          if (isClosed) return;
          await _attempt(request, canReplaceKey: false);
          return;
        }
        final unknown = _outcomeUnknown(failure);
        final notSent = failure is HumanVerificationUnavailableFailure || failure is RateLimitedFailure;
        DateTime? retryAt;
        if (failure is RateLimitedFailure) {
          final wait = failure.retryAfter;
          retryAt = _now().add(wait == null || wait <= Duration.zero ? defaultRetryAfter : wait);
          _blockedUntil = retryAt;
          _blockFailure = failure;
        }
        if (unknown || notSent) {
          _pending.put(_scope, key, unknown: unknown);
        } else {
          _forgetKey();
        }
        if (!isClosed) {
          emit(NotifyState(status: NotifyStatus.failed, failure: failure, outcomeUnknown: unknown, notSent: notSent, retryAt: retryAt));
        }
    }
  }

  /// Back to the form (after a refusal the customer has read).
  void dismiss() {
    if (isClosed || _busy) return;
    final pending = _pending.pendingFor(_scope);
    emit(NotifyState(outcomeUnknown: pending?.unknown ?? false));
  }

  void _forgetKey() {
    _key = null;
    _fingerprint = null;
    _pending.remove(_scope);
  }

  /// Sent, and the app cannot know whether it arrived.
  static bool _outcomeUnknown(Failure failure) =>
      failure is NetworkFailure || failure is ServerFailure || failure is IdempotencyInProgressFailure;
}
