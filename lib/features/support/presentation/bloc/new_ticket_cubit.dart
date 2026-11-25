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

enum CategoriesStatus { loading, ready, unavailable, error }

enum NewTicketStatus { editing, submitting, done, unavailable }

/// A draft the device refused before anything was sent.
enum NewTicketIssue { noCategory, bodyEmpty, bodyTooLong }

enum NewTicketNotice {
  none,

  /// Sent, and the app does not know whether it arrived (a lost answer, a server error, still processing).
  unknownOutcome,

  /// The text changed after an unknown outcome: the customer is shown their latest tickets before anything is sent.
  checkFirst,

  /// Not sent or not accepted yet because of the hourly limit: the button is held until [NewTicketState.retryAt].
  notSent,
}

/// The ticket text is never part of this state: it passes through
/// [NewTicketCubit.submit] and is gone when that returns. The page keeps the
/// draft in its own text field (memory only) and clears it on success.
class NewTicketState extends Equatable {
  const NewTicketState({
    this.categoriesStatus = CategoriesStatus.loading,
    this.categories = const [],
    this.status = NewTicketStatus.editing,
    this.reference,
    this.failure,
    this.issue,
    this.notice = NewTicketNotice.none,
    this.retryAt,
    this.recent = const [],
  });

  final CategoriesStatus categoriesStatus;
  final List<TicketCategory> categories;
  final NewTicketStatus status;

  /// The reference of the ticket just opened.
  final String? reference;
  final Failure? failure;
  final NewTicketIssue? issue;
  final NewTicketNotice notice;

  /// While in the future no ticket is sent: the server's `Retry-After`.
  final DateTime? retryAt;

  /// The customer's latest tickets, shown with [NewTicketNotice.checkFirst].
  final List<Ticket> recent;

  @override
  List<Object?> get props => [categoriesStatus, categories, status, reference, failure, issue, notice, retryAt, recent];
}

/// Opens a ticket. ONE idempotency key per attempt (see [KeyedAttempt]): a double
/// tap sends one request; a retry of the same text after a lost or unfinished
/// request, even from a screen opened later, reuses the key (one ticket); a
/// changed text after an unknown outcome reads the customer's tickets first; a
/// final answer starts afresh. Nothing is emitted after the screen is closed,
/// but the bookkeeping of the key still is.
class NewTicketCubit extends Cubit<NewTicketState> {
  NewTicketCubit(
    this._repository, {
    String Function()? newKey,
    PendingTicketKeys? pending,
    String scope = '',
    DateTime Function()? now,
  }) : _attempt = KeyedAttempt(pending: pending ?? PendingTicketKeys(), scope: scope, newKey: newKey ?? newIdempotencyKey),
       _now = now ?? DateTime.now,
       super(const NewTicketState()) {
    loadCategories();
  }

  final SupportTicketsRepository _repository;
  final KeyedAttempt _attempt;
  final DateTime Function() _now;

  /// Without a `Retry-After` hint the customer waits this long.
  static const defaultRetryAfter = Duration(minutes: 1);

  /// The clock the wait is measured with (the page counts down against the same one).
  DateTime now() => _now();

  bool _loadingCategories = false;
  DateTime? _blockedUntil;

  bool get _busy => state.status == NewTicketStatus.submitting;

  NewTicketState _next({
    NewTicketStatus status = NewTicketStatus.editing,
    String? reference,
    Failure? failure,
    NewTicketIssue? issue,
    NewTicketNotice notice = NewTicketNotice.none,
    DateTime? retryAt,
    List<Ticket> recent = const [],
  }) => NewTicketState(
    categoriesStatus: state.categoriesStatus,
    categories: state.categories,
    status: status,
    reference: reference,
    failure: failure,
    issue: issue,
    notice: notice,
    retryAt: retryAt,
    recent: recent,
  );

  Future<void> loadCategories() async {
    if (_loadingCategories || isClosed) return;
    _loadingCategories = true;
    if (state.categoriesStatus != CategoriesStatus.ready) {
      emit(NewTicketState(status: state.status, failure: state.failure, notice: state.notice, retryAt: state.retryAt));
    }
    final result = await _repository.categories();
    _loadingCategories = false;
    if (isClosed) return;
    result.match(
      (failure) => emit(
        NewTicketState(
          categoriesStatus: failure is TicketsNotAvailableFailure ? CategoriesStatus.unavailable : CategoriesStatus.error,
          categories: state.categories,
          status: failure is TicketsNotAvailableFailure ? NewTicketStatus.unavailable : state.status,
          failure: state.status == NewTicketStatus.editing && state.failure != null ? state.failure : failure,
          notice: state.notice,
          retryAt: state.retryAt,
          recent: state.recent,
          reference: state.reference,
        ),
      ),
      (categories) => emit(
        NewTicketState(
          categoriesStatus: CategoriesStatus.ready,
          categories: categories,
          status: state.status,
          failure: state.failure is TicketCategoryGoneFailure ? state.failure : null,
          notice: state.notice,
          retryAt: state.retryAt,
          recent: state.recent,
          reference: state.reference,
          issue: state.issue == NewTicketIssue.noCategory ? null : state.issue,
        ),
      ),
    );
  }

  Future<void> submit({required String? categoryKey, required String body}) async {
    if (isClosed || _busy || state.status == NewTicketStatus.done) return;
    final text = body.trim();
    final issue = _issue(categoryKey, text);
    if (issue != null) {
      emit(_next(issue: issue, notice: state.notice, retryAt: state.retryAt, recent: state.recent));
      return;
    }
    final until = _blockedUntil;
    if (until != null && _now().isBefore(until)) {
      // Held: nothing is sent until the server's wait is over.
      emit(_next(failure: state.failure, notice: NewTicketNotice.notSent, retryAt: until));
      return;
    }
    await _send(categoryKey!, text, canReplaceKey: true);
  }

  NewTicketIssue? _issue(String? categoryKey, String text) {
    if (categoryKey == null || !state.categories.any((c) => c.key == categoryKey)) return NewTicketIssue.noCategory;
    if (text.isEmpty) return NewTicketIssue.bodyEmpty;
    if (text.runes.length > ticketBodyMaxLength) return NewTicketIssue.bodyTooLong; // code points, as the server counts
    return null;
  }

  Future<void> _send(String categoryKey, String text, {required bool canReplaceKey}) async {
    final fingerprint = PendingTicketKeys.fingerprint(categoryKey, text);
    final key = _attempt.begin(fingerprint);
    if (key == null) {
      await _checkFirst();
      return;
    }
    if (!isClosed) emit(_next(status: NewTicketStatus.submitting));
    final result = await _repository.create(categoryKey: categoryKey, body: text, idempotencyKey: key);
    // Bookkeeping runs even when the screen was closed; only the emits are guarded.
    switch (result) {
      case Right(value: final reference):
        _attempt.settle();
        _blockedUntil = null;
        if (!isClosed) emit(_next(status: NewTicketStatus.done, reference: reference));
      case Left(value: final failure):
        if (canReplaceKey && failure is ValidationFailure && failure.code == 'idempotency_key_reused') {
          // The server says this key belongs to another request: nothing was created, so a new key is safe (once).
          _attempt.settle();
          if (isClosed) return;
          await _send(categoryKey, text, canReplaceKey: false);
          return;
        }
        if (failure is TicketsNotAvailableFailure) {
          _attempt.settle();
          if (!isClosed) emit(_next(status: NewTicketStatus.unavailable, failure: failure));
          return;
        }
        if (failure is RateLimitedFailure) {
          final wait = failure.retryAfter;
          final retryAt = _now().add(wait == null || wait <= Duration.zero ? defaultRetryAfter : wait);
          _blockedUntil = retryAt;
          // A 429 stored nothing on the server: the attempt is settled (a changed text needs no check).
          _attempt.settle();
          if (!isClosed) emit(_next(failure: failure, notice: NewTicketNotice.notSent, retryAt: retryAt));
          return;
        }
        if (_outcomeUnknown(failure)) {
          if (!isClosed) emit(_next(failure: failure, notice: NewTicketNotice.unknownOutcome));
          return;
        }
        // A final answer from the server: the key is dropped, the draft stays with the customer.
        _attempt.settle();
        if (!isClosed) emit(_next(failure: failure));
        if (failure is TicketCategoryGoneFailure) unawaited(loadCategories());
    }
  }

  /// The text changed while an earlier attempt is unknown: read the latest tickets, show them, send nothing.
  Future<void> _checkFirst() async {
    if (!isClosed) emit(_next(status: NewTicketStatus.submitting));
    final result = await _repository.list();
    if (isClosed) return;
    switch (result) {
      case Right(value: final page):
        // Only a read the customer can see counts as the check.
        _attempt.acknowledge();
        emit(_next(notice: NewTicketNotice.checkFirst, recent: page.items.take(3).toList()));
      case Left():
        // Not acknowledged: the unknown-outcome notice stays and nothing is sent.
        emit(_next(notice: NewTicketNotice.unknownOutcome));
    }
  }

  /// Back to the form (after a refusal the customer has read).
  void dismiss() {
    if (isClosed || _busy) return;
    emit(_next(notice: state.notice == NewTicketNotice.notSent ? NewTicketNotice.notSent : NewTicketNotice.none, retryAt: state.retryAt));
  }

  /// Sent, and the app cannot know whether it arrived.
  static bool _outcomeUnknown(Failure failure) =>
      failure is NetworkFailure || failure is ServerFailure || failure is IdempotencyInProgressFailure;
}
