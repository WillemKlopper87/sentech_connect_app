import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_tickets_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/keyed_attempt.dart';

enum ThreadStatus { loading, ready, unavailable, notFound, error }

enum ReplyStatus { idle, sending, sent }

/// A reply the device refused before anything was sent.
enum ReplyIssue { empty, tooLong }

enum ReplyNotice {
  none,

  /// Sent, and the app does not know whether it arrived.
  unknownOutcome,

  /// The text changed after an unknown outcome: the thread was read again and nothing was sent.
  checkFirst,

  /// The ticket is closed (it was closed by support, or while the customer was writing).
  closed,

  /// Held because of the hourly limit until [ThreadState.retryAt].
  notSent,
}

/// The reply text is never part of this state: it passes through
/// [TicketThreadCubit.reply]; the page keeps the draft in its text field and
/// clears it when [replyStatus] becomes [ReplyStatus.sent].
const Object _keep = Object();

class ThreadState extends Equatable {
  const ThreadState({
    this.status = ThreadStatus.loading,
    this.thread,
    this.failure,
    this.replyStatus = ReplyStatus.idle,
    this.replyFailure,
    this.notice = ReplyNotice.none,
    this.retryAt,
    this.closing = false,
    this.closeFailure,
    this.replyIssue,
  });

  final ThreadStatus status;
  final TicketThread? thread;
  final Failure? failure;
  final ReplyStatus replyStatus;
  final Failure? replyFailure;
  final ReplyNotice notice;
  final DateTime? retryAt;

  /// "Mark as solved" is in flight.
  final bool closing;
  final Failure? closeFailure;

  /// The last reply was refused on the device (empty or over the limit).
  final ReplyIssue? replyIssue;

  @override
  List<Object?> get props => [status, thread, failure, replyStatus, replyFailure, notice, retryAt, closing, closeFailure, replyIssue];
}

/// One ticket and its messages. The thread is read on open and on pull to
/// refresh (no polling). A reply follows the one-key-per-attempt rule
/// ([KeyedAttempt]); a read that started before a reply was sent never
/// overwrites it (each send and each read bumps a generation, and an older read
/// is dropped). Nothing is emitted after the screen is closed.
class TicketThreadCubit extends Cubit<ThreadState> {
  TicketThreadCubit(
    this._repository,
    this.reference, {
    String Function()? newKey,
    PendingTicketKeys? pending,
    String scope = '',
    DateTime Function()? now,
  }) : _attempt = KeyedAttempt(pending: pending ?? PendingTicketKeys(), scope: scope, newKey: newKey ?? newIdempotencyKey),
       _now = now ?? DateTime.now,
       super(const ThreadState()) {
    load();
  }

  final SupportTicketsRepository _repository;
  final String reference;
  final KeyedAttempt _attempt;
  final DateTime Function() _now;

  /// Without a `Retry-After` hint the customer waits this long.
  static const defaultRetryAfter = Duration(minutes: 1);

  /// The clock the wait is measured with (the page counts down against the same one).
  DateTime now() => _now();

  int _generation = 0;
  DateTime? _blockedUntil;

  bool get _sending => state.replyStatus == ReplyStatus.sending;

  /// A copy with the given fields; a field that is not given keeps its value
  /// (the failures too, until something sets them or [_clear] drops them).
  ThreadState _with({
    ThreadStatus? status,
    TicketThread? thread,
    Object? replyFailure = _keep,
    ReplyStatus? replyStatus,
    ReplyNotice? notice,
    DateTime? retryAt,
    bool? closing,
    Object? closeFailure = _keep,
    Object? replyIssue = _keep,
  }) => ThreadState(
    status: status ?? state.status,
    thread: thread ?? state.thread,
    failure: state.failure,
    replyStatus: replyStatus ?? state.replyStatus,
    replyFailure: identical(replyFailure, _keep) ? state.replyFailure : replyFailure as Failure?,
    notice: notice ?? state.notice,
    retryAt: retryAt ?? state.retryAt,
    closing: closing ?? state.closing,
    closeFailure: identical(closeFailure, _keep) ? state.closeFailure : closeFailure as Failure?,
    replyIssue: identical(replyIssue, _keep) ? state.replyIssue : replyIssue as ReplyIssue?,
  );

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    final visible = keepVisible && state.thread != null;
    if (!visible) emit(const ThreadState());
    final result = await _repository.get(reference);
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) {
        if (visible) return; // the thread already on screen stays; a pull that failed says nothing worse
        emit(
          ThreadState(
            status: switch (failure) {
              TicketsNotAvailableFailure() => ThreadStatus.unavailable,
              TicketNotFoundFailure() => ThreadStatus.notFound,
              _ => ThreadStatus.error,
            },
            failure: failure,
          ),
        );
      },
      (thread) => emit(_with(status: ThreadStatus.ready, thread: thread)),
    );
  }

  Future<void> refresh() => load(keepVisible: true);

  /// Sends [body] as a reply. A closed ticket takes none.
  Future<void> reply(String body) async {
    final thread = state.thread;
    if (isClosed || _sending || thread == null || state.status != ThreadStatus.ready || thread.isClosed) return;
    final text = body.trim();
    // The server counts code points, so an emoji is one, not two.
    final length = text.runes.length;
    if (text.isEmpty || length > ticketBodyMaxLength) {
      emit(_with(replyIssue: text.isEmpty ? ReplyIssue.empty : ReplyIssue.tooLong));
      return;
    }
    final until = _blockedUntil;
    if (until != null && _now().isBefore(until)) {
      emit(_with(notice: ReplyNotice.notSent, retryAt: until));
      return;
    }
    await _send(text, canReplaceKey: true);
  }

  Future<void> _send(String text, {required bool canReplaceKey}) async {
    // A retry of an attempt with an unknown outcome may already be on screen (a read showed it).
    final replay = _attempt.hasUnknown;
    final before = _countMine(state.thread, text);
    final key = _attempt.begin(PendingTicketKeys.fingerprint(reference, text));
    if (key == null) {
      await _checkFirst();
      return;
    }
    // A read that started before this send must not overwrite the result of it.
    ++_generation;
    if (!isClosed) emit(_with(replyStatus: ReplyStatus.sending, notice: ReplyNotice.none, replyFailure: null, replyIssue: null));
    final result = await _repository.reply(reference, body: text, idempotencyKey: key);
    switch (result) {
      case Right(value: final header):
        _attempt.settle();
        _blockedUntil = null;
        if (isClosed) return;
        final current = state.thread;
        if (current != null) {
          // Shown once: not again if a read already shows it (a fresh send adds one more than before;
          // a replay is already there if any identical message is). Kept if the follow-up read fails.
          final shown = _countMine(current, text);
          final already = replay ? shown > 0 : shown > before;
          final updated = current.withHeader(header);
          emit(
            _with(
              thread: already
                  ? updated
                  : updated.withMessages([...current.messages, TicketMessage(author: TicketAuthor.you, body: text, createdAt: _now().toUtc())]),
              replyStatus: ReplyStatus.sent,
              notice: ReplyNotice.none,
              replyFailure: null,
            ),
          );
        } else {
          emit(_with(replyStatus: ReplyStatus.sent, notice: ReplyNotice.none, replyFailure: null));
        }
        unawaited(_readAfterSend());
      case Left(value: final failure):
        if (canReplaceKey && failure is ValidationFailure && failure.code == 'idempotency_key_reused') {
          _attempt.settle();
          if (isClosed) return;
          await _send(text, canReplaceKey: false);
          return;
        }
        if (failure is TicketsNotAvailableFailure) {
          _attempt.settle();
          if (!isClosed) {
            emit(const ThreadState(status: ThreadStatus.unavailable, failure: TicketsNotAvailableFailure()));
          }
          return;
        }
        if (failure is RateLimitedFailure) {
          final wait = failure.retryAfter;
          final retryAt = _now().add(wait == null || wait <= Duration.zero ? defaultRetryAfter : wait);
          _blockedUntil = retryAt;
          // A 429 stored nothing on the server: the attempt is settled (a changed text needs no check).
          _attempt.settle();
          if (!isClosed) {
            emit(_with(replyStatus: ReplyStatus.idle, replyFailure: failure, notice: ReplyNotice.notSent, retryAt: retryAt));
          }
          return;
        }
        if (failure is NetworkFailure || failure is ServerFailure || failure is IdempotencyInProgressFailure) {
          if (!isClosed) {
            emit(_with(replyStatus: ReplyStatus.idle, replyFailure: failure, notice: ReplyNotice.unknownOutcome));
          }
          return;
        }
        // A final answer: the key is dropped, the draft stays with the customer.
        _attempt.settle();
        final refused = failure is TicketClosedFailure;
        if (!isClosed) {
          emit(_with(replyStatus: ReplyStatus.idle, replyFailure: failure, notice: refused ? ReplyNotice.closed : ReplyNotice.none));
        }
        // The ticket changed under the customer: show the thread as it is now.
        if (failure is TicketClosedFailure || failure is TicketNotFoundFailure) unawaited(load(keepVisible: true));
    }
  }

  Future<void> _readAfterSend() async {
    final generation = ++_generation;
    final result = await _repository.get(reference);
    if (isClosed || generation != _generation) return;
    result.match((_) {}, (thread) => emit(_with(thread: thread)));
  }

  /// The text changed while an earlier attempt is unknown: read the thread, show it, send nothing.
  Future<void> _checkFirst() async {
    final generation = ++_generation;
    if (!isClosed) emit(_with(replyStatus: ReplyStatus.sending, notice: ReplyNotice.none));
    final result = await _repository.get(reference);
    if (isClosed) return;
    final read = generation == _generation ? result.match((_) => null, (thread) => thread) : null;
    if (read == null) {
      // Nothing was shown to the customer: not acknowledged, the unknown-outcome notice stays, nothing is sent.
      emit(_with(replyStatus: ReplyStatus.idle, notice: ReplyNotice.unknownOutcome));
      return;
    }
    _attempt.acknowledge();
    emit(_with(thread: read, replyStatus: ReplyStatus.idle, notice: ReplyNotice.checkFirst));
  }

  static int _countMine(TicketThread? thread, String text) =>
      thread == null ? 0 : thread.messages.where((m) => m.author == TicketAuthor.you && m.body == text).length;

  /// The customer marks the ticket solved. Only the server's answer changes the status shown.
  Future<void> closeTicket() async {
    final thread = state.thread;
    if (isClosed || state.closing || thread == null || thread.isClosed || thread.isResolved) return;
    emit(_with(closing: true, closeFailure: null));
    final result = await _repository.close(reference);
    if (isClosed) return;
    switch (result) {
      case Right(value: final header):
        _generation++;
        emit(_with(thread: state.thread?.withHeader(header), closing: false));
      case Left(value: final failure):
        emit(_with(closing: false, closeFailure: failure));
        // The ticket changed (closed, already solved, a version conflict): show it as it is now.
        if (failure is TicketClosedFailure || failure is TicketAlreadyResolvedFailure || failure is TicketChangedFailure) {
          unawaited(load(keepVisible: true));
        }
    }
  }
}
