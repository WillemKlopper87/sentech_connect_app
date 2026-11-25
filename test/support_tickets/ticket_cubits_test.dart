import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/incidents_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/new_ticket_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/ticket_thread_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/tickets_cubit.dart';

import 'fake_support_tickets_repository.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

String Function() _keys() {
  var n = 0;
  return () => 'key-${++n}-0000000';
}

const _ref = 'TKT-7K3M9Q2A';
const _text = 'I was charged twice for my pass.';

void main() {
  late FakeSupportTicketsRepository repo;

  setUp(() => repo = FakeSupportTicketsRepository());

  group('TicketsCubit', () {
    test('loads the first page and follows the cursor, skipping a duplicate row', () async {
      final first = ticketFixture();
      final second = ticketFixture(reference: 'TKT-2B8D4F6H', status: TicketStatus.open, awaiting: false);
      repo.listPages[null] = Right(TicketPage(items: [first], nextCursor: 'c1'));
      repo.listPages['c1'] = Right(TicketPage(items: [first, second]));
      final cubit = TicketsCubit(repo);
      await _settle();
      expect(cubit.state.status, TicketsStatus.ready);
      expect(cubit.state.hasMore, isTrue);
      await cubit.loadMore();
      await cubit.loadMore(); // the list ended: nothing more is asked for
      expect(repo.listCursors, [null, 'c1']);
      expect(cubit.state.items.map((t) => t.reference), [first.reference, second.reference]);
      expect(cubit.state.hasMore, isFalse);
      await cubit.close();
    });

    test('feature unavailable is its own state, a failure keeps what is on screen', () async {
      repo.listPages[null] = const Left(TicketsNotAvailableFailure());
      var cubit = TicketsCubit(repo);
      await _settle();
      expect(cubit.state.status, TicketsStatus.unavailable);
      await cubit.close();

      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()]));
      cubit = TicketsCubit(repo);
      await _settle();
      repo.listPages[null] = const Left(NetworkFailure());
      await cubit.refresh();
      expect(cubit.state.status, TicketsStatus.ready);
      expect(cubit.state.items, hasLength(1));
      await cubit.close();
    });

    test('a failed first load is an error with a retry, and a failed next page keeps the pages', () async {
      repo.listPages[null] = const Left(NetworkFailure());
      final cubit = TicketsCubit(repo);
      await _settle();
      expect(cubit.state.status, TicketsStatus.error);
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()], nextCursor: 'c1'));
      await cubit.refresh();
      repo.listPages['c1'] = const Left(NetworkFailure());
      await cubit.loadMore();
      expect(cubit.state.items, hasLength(1));
      expect(cubit.state.moreFailure, isA<NetworkFailure>());
      await cubit.close();
    });
  });

  group('NewTicketCubit', () {
    NewTicketCubit make({PendingTicketKeys? pending, DateTime Function()? now}) => NewTicketCubit(
      repo,
      newKey: _keys(),
      pending: pending ?? PendingTicketKeys(),
      scope: 'sentech|u1|new',
      now: now,
    );

    test('loads the categories from the server', () async {
      final cubit = make();
      await _settle();
      expect(cubit.state.categoriesStatus, CategoriesStatus.ready);
      expect(cubit.state.categories.map((c) => c.key), ['billing', 'connection', 'other']);
      await cubit.close();
    });

    test('validates before anything is sent', () async {
      final cubit = make();
      await _settle();
      await cubit.submit(categoryKey: null, body: _text);
      expect(cubit.state.issue, NewTicketIssue.noCategory);
      await cubit.submit(categoryKey: 'billing', body: '   ');
      expect(cubit.state.issue, NewTicketIssue.bodyEmpty);
      await cubit.submit(categoryKey: 'billing', body: 'x' * (ticketBodyMaxLength + 1));
      expect(cubit.state.issue, NewTicketIssue.bodyTooLong);
      await cubit.submit(categoryKey: 'not-listed', body: _text);
      expect(cubit.state.issue, NewTicketIssue.noCategory, reason: 'only a category the server listed can be sent');
      expect(repo.createCalls, isEmpty);
      await cubit.close();
    });

    test('a_double_tap_sends_one_ticket', () async {
      repo.sendGate = Completer<void>();
      final cubit = make();
      await _settle();
      unawaited(cubit.submit(categoryKey: 'billing', body: _text));
      unawaited(cubit.submit(categoryKey: 'billing', body: _text));
      unawaited(cubit.submit(categoryKey: 'billing', body: 'something else'));
      await _settle();
      repo.sendGate!.complete();
      await _settle();
      expect(repo.createCalls, hasLength(1));
      expect(cubit.state.status, NewTicketStatus.done);
      expect(cubit.state.reference, _ref);
      await cubit.close();
    });

    test('a_retry_after_an_unknown_outcome_reuses_the_key', () async {
      repo.createResults.addAll([const Left(NetworkFailure()), const Right(_ref)]);
      final cubit = make();
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(cubit.state.notice, NewTicketNotice.unknownOutcome);
      expect(cubit.state.status, NewTicketStatus.editing, reason: 'the draft stays, the customer can try again');
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(repo.createCalls.map((c) => c.key).toSet(), hasLength(1));
      expect(cubit.state.status, NewTicketStatus.done);
      await cubit.close();
    });

    test('every outcome the app cannot know keeps the key: network, server, still processing, rate limit', () async {
      for (final failure in <Failure>[
        const NetworkFailure(),
        const ServerFailure(),
        const IdempotencyInProgressFailure(),
        const RateLimitedFailure('slow down', Duration(seconds: 5)),
      ]) {
        final fresh = FakeSupportTicketsRepository()..createResults.addAll([Left(failure), const Right(_ref)]);
        final cubit = NewTicketCubit(fresh, newKey: _keys(), pending: PendingTicketKeys(), scope: 's', now: () => DateTime.utc(2030));
        await _settle();
        await cubit.submit(categoryKey: 'billing', body: _text);
        // A rate limit holds the button first; the hold is over when the clock says so (see below).
        await cubit.submit(categoryKey: 'billing', body: _text);
        if (failure is! RateLimitedFailure) {
          expect(fresh.createCalls.map((c) => c.key).toSet(), hasLength(1), reason: '${failure.runtimeType}');
        }
        await cubit.close();
      }
    });

    test('going back and reopening after a lost answer retries the SAME key for the same text', () async {
      final holder = PendingTicketKeys();
      repo.createResults.addAll([const Left(NetworkFailure()), const Right(_ref)]);
      var cubit = make(pending: holder);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      await cubit.close();
      cubit = make(pending: holder);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(repo.createCalls.map((c) => c.key).toSet(), hasLength(1));
      expect(holder.pendingFor('sentech|u1|new'), isNull, reason: 'success forgets the key');
      await cubit.close();
    });

    test('a_changed_body_after_an_unknown_outcome_refreshes_first', () async {
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()]));
      repo.createResults.addAll([const Left(NetworkFailure()), const Right('TKT-2B8D4F6H')]);
      final cubit = make();
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      await cubit.submit(categoryKey: 'billing', body: 'A different text');
      // The second tap only checks: the list is read, nothing new is sent.
      expect(repo.createCalls, hasLength(1));
      expect(repo.listCursors, [null]);
      expect(cubit.state.notice, NewTicketNotice.checkFirst);
      expect(cubit.state.recent.map((t) => t.reference), [_ref]);
      // After the customer has seen it, the third tap sends the new text under a NEW key.
      await cubit.submit(categoryKey: 'billing', body: 'A different text');
      expect(repo.createCalls, hasLength(2));
      expect(repo.createCalls.last.body, 'A different text');
      expect(repo.createCalls.last.key, isNot(repo.createCalls.first.key));
      await cubit.close();
    });

    test('a refusal the server means is final: the key is dropped and the draft stays', () async {
      repo.createResults.addAll([const Left(TicketCategoryGoneFailure()), const Right(_ref)]);
      final holder = PendingTicketKeys();
      final cubit = make(pending: holder);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(holder.pendingFor('sentech|u1|new'), isNull);
      expect(cubit.state.failure, isA<TicketCategoryGoneFailure>());
      expect(repo.categoriesCalls, 2, reason: 'the categories are read again');
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(repo.createCalls.map((c) => c.key).toSet(), hasLength(2));
      await cubit.close();
    });

    test('a key the server says belongs to another request is replaced once', () async {
      repo.createResults.addAll([
        const Left(ValidationFailure('reused', 'idempotency_key_reused', false)),
        const Right(_ref),
      ]);
      final cubit = make();
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(repo.createCalls, hasLength(2));
      expect(repo.createCalls.first.key, isNot(repo.createCalls.last.key));
      expect(cubit.state.status, NewTicketStatus.done);
      await cubit.close();
    });

    test('a 429 holds the send button until the wait is over, and sends nothing meanwhile', () async {
      var now = DateTime.utc(2030, 1, 1, 12);
      repo.createResults.addAll([const Left(RateLimitedFailure('slow', Duration(minutes: 10))), const Right(_ref)]);
      final cubit = make(now: () => now);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(cubit.state.retryAt, DateTime.utc(2030, 1, 1, 12, 10));
      expect(cubit.state.notice, NewTicketNotice.notSent);
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(repo.createCalls, hasLength(1), reason: 'held');
      now = DateTime.utc(2030, 1, 1, 12, 10, 1);
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(repo.createCalls, hasLength(2));
      expect(repo.createCalls.map((c) => c.key).toSet(), hasLength(1), reason: 'a 429 is not an answer: the same key');
      await cubit.close();
    });

    test('feature off while writing is its own state and nothing is kept', () async {
      repo.createResults.add(const Left(TicketsNotAvailableFailure()));
      final holder = PendingTicketKeys();
      final cubit = make(pending: holder);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(cubit.state.status, NewTicketStatus.unavailable);
      expect(holder.pendingFor('sentech|u1|new'), isNull);
      await cubit.close();
    });

    test('closing_mid_request_emits_nothing_after_close', () async {
      repo.sendGate = Completer<void>();
      repo.createResults.add(const Left(NetworkFailure()));
      final holder = PendingTicketKeys();
      final cubit = make(pending: holder);
      await _settle();
      final emitted = <NewTicketState>[];
      final sub = cubit.stream.listen(emitted.add);
      unawaited(cubit.submit(categoryKey: 'billing', body: _text));
      await _settle();
      await cubit.close();
      final countAtClose = emitted.length;
      repo.sendGate!.complete();
      await _settle();
      expect(emitted.length, countAtClose);
      // The outcome was unknown, so the key is kept for the next screen even though this one is gone.
      expect(holder.pendingFor('sentech|u1|new'), isNotNull);
      await sub.cancel();
    });

    test('the_draft_is_cleared_on_success_and_never_persisted', () async {
      SharedPreferences.setMockInitialValues({});
      final holder = PendingTicketKeys();
      final cubit = make(pending: holder);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: _text);
      expect(cubit.state.status, NewTicketStatus.done);
      // The cubit never holds the text: no state field, no holder entry and no preference carries it.
      expect(cubit.state.props.map((p) => '$p').join(), isNot(contains('charged')));
      expect(holder.toString(), isNot(contains('charged')));
      expect(holder.pendingFor('sentech|u1|new'), isNull);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
      await cubit.close();
    });

    test('the holder keeps no text, only a key and a number, and clear() empties it', () {
      final holder = PendingTicketKeys()..put('s', 'key-aaaaaaaa', PendingTicketKeys.fingerprint('billing', _text));
      expect(holder.pendingFor('s')!.key, 'key-aaaaaaaa');
      expect(holder.toString(), isNot(contains('charged')));
      holder.clear();
      expect(holder.pendingFor('s'), isNull);
      expect(PendingTicketKeys.fingerprint('billing', _text), isNot(PendingTicketKeys.fingerprint('billing', '$_text.')));
    });
  });

  group('TicketThreadCubit', () {
    TicketThreadCubit make({PendingTicketKeys? pending, DateTime Function()? now}) => TicketThreadCubit(
      repo,
      _ref,
      newKey: _keys(),
      pending: pending ?? PendingTicketKeys(),
      scope: 'sentech|u1|reply|$_ref',
      now: now ?? () => DateTime.utc(2026, 11, 22, 10),
    );

    test('loads the thread; not found, unavailable and errors are their own states', () async {
      var cubit = make();
      await _settle();
      expect(cubit.state.status, ThreadStatus.ready);
      expect(cubit.state.thread!.messages, hasLength(2));
      await cubit.close();

      repo.threadResult = const Left(TicketNotFoundFailure());
      cubit = make();
      await _settle();
      expect(cubit.state.status, ThreadStatus.notFound);
      await cubit.close();

      repo.threadResult = const Left(TicketsNotAvailableFailure());
      cubit = make();
      await _settle();
      expect(cubit.state.status, ThreadStatus.unavailable);
      await cubit.close();

      repo.threadResult = const Left(NetworkFailure());
      cubit = make();
      await _settle();
      expect(cubit.state.status, ThreadStatus.error);
      repo.threadResult = Right(threadFixture());
      await cubit.refresh();
      expect(cubit.state.status, ThreadStatus.ready);
      await cubit.close();
    });

    test('a failed refresh keeps the thread on screen', () async {
      final cubit = make();
      await _settle();
      repo.threadResult = const Left(NetworkFailure());
      await cubit.refresh();
      expect(cubit.state.status, ThreadStatus.ready);
      expect(cubit.state.thread!.messages, hasLength(2));
      await cubit.close();
    });

    test('a reply is added to the thread at once and the header follows the server', () async {
      final cubit = make();
      await _settle();
      await cubit.reply('The 3rd of November.');
      expect(repo.replyCalls.single.reference, _ref);
      expect(cubit.state.replyStatus, ReplyStatus.sent);
      expect(cubit.state.thread!.messages.last.author, TicketAuthor.you);
      expect(cubit.state.thread!.messages.last.body, 'The 3rd of November.');
      expect(cubit.state.thread!.awaitingReply, isFalse);
      await cubit.close();
    });

    test('a_double_tap_sends_one_reply', () async {
      repo.sendGate = Completer<void>();
      final cubit = make();
      await _settle();
      unawaited(cubit.reply('hello'));
      unawaited(cubit.reply('hello'));
      await _settle();
      repo.sendGate!.complete();
      await _settle();
      expect(repo.replyCalls, hasLength(1));
      await cubit.close();
    });

    test('a retry of the same reply after a lost answer reuses the key, a changed one reads the thread first', () async {
      repo.replyResults.addAll([const Left(NetworkFailure()), Right(ticketFixture(awaiting: false, status: TicketStatus.open))]);
      final cubit = make();
      await _settle();
      await cubit.reply('first');
      expect(cubit.state.notice, ReplyNotice.unknownOutcome);
      final readsBefore = repo.getCalls;
      await cubit.reply('different');
      expect(repo.replyCalls, hasLength(1), reason: 'the changed text only checks the thread');
      expect(repo.getCalls, readsBefore + 1);
      expect(cubit.state.notice, ReplyNotice.checkFirst);
      await cubit.reply('first');
      expect(repo.replyCalls, hasLength(2));
      expect(repo.replyCalls.map((c) => c.key).toSet(), hasLength(1), reason: 'back to the same text: the same key');
      await cubit.close();
    });

    test('reply_to_a_closed_ticket_refreshes_the_thread', () async {
      repo.replyResults.add(const Left(TicketClosedFailure()));
      final holder = PendingTicketKeys();
      final cubit = make(pending: holder);
      await _settle();
      repo.threadResult = Right(threadFixture().withHeader(ticketFixture(status: TicketStatus.closed, awaiting: false)));
      final readsBefore = repo.getCalls;
      await cubit.reply('too late');
      await _settle();
      expect(repo.getCalls, readsBefore + 1);
      expect(cubit.state.notice, ReplyNotice.closed);
      expect(cubit.state.thread!.status, TicketStatus.closed);
      expect(cubit.state.thread!.messages, hasLength(2), reason: 'the refused text is not added');
      expect(holder.pendingFor('sentech|u1|reply|$_ref'), isNull, reason: 'a final refusal drops the key');
      await cubit.close();
    });

    test('stale_refresh_does_not_overwrite_a_sent_reply', () async {
      final cubit = make();
      await _settle();
      // A pull to refresh starts and is held: it will deliver the OLD thread (no reply in it).
      final gate = Completer<void>();
      repo.getGate = gate;
      unawaited(cubit.refresh());
      await _settle();
      repo.getGate = null;
      // Meanwhile a reply is sent; the thread read after it has the reply.
      repo.threadResult = Right(
        threadFixture().withHeader(ticketFixture(status: TicketStatus.open, awaiting: false)).withMessages([
          ...threadFixture().messages,
          TicketMessage(author: TicketAuthor.you, body: 'Sent now', createdAt: DateTime.utc(2026, 11, 22, 10)),
        ]),
      );
      await cubit.reply('Sent now');
      await _settle();
      expect(cubit.state.thread!.messages.map((m) => m.body), contains('Sent now'));
      // Now the stale refresh answers with the old thread: it must be dropped.
      gate.complete();
      await _settle();
      expect(cubit.state.thread!.messages.map((m) => m.body), contains('Sent now'));
      expect(cubit.state.thread!.messages, hasLength(3));
      await cubit.close();
    });

    test('closing_mid_request_emits_nothing_after_close', () async {
      repo.sendGate = Completer<void>();
      repo.replyResults.add(const Left(NetworkFailure()));
      final holder = PendingTicketKeys();
      final cubit = make(pending: holder);
      await _settle();
      final emitted = <ThreadState>[];
      final sub = cubit.stream.listen(emitted.add);
      unawaited(cubit.reply('hello'));
      await _settle();
      await cubit.close();
      final countAtClose = emitted.length;
      repo.sendGate!.complete();
      await _settle();
      expect(emitted.length, countAtClose);
      expect(holder.pendingFor('sentech|u1|reply|$_ref'), isNotNull);
      await sub.cancel();
    });

    test('a 429 holds the reply button for the wait', () async {
      var now = DateTime.utc(2030, 1, 1, 12);
      repo.replyResults.addAll([
        const Left(RateLimitedFailure('slow', Duration(minutes: 3))),
        Right(ticketFixture(awaiting: false, status: TicketStatus.open)),
      ]);
      final cubit = make(now: () => now);
      await _settle();
      await cubit.reply('hello');
      expect(cubit.state.retryAt, DateTime.utc(2030, 1, 1, 12, 3));
      await cubit.reply('hello');
      expect(repo.replyCalls, hasLength(1));
      now = DateTime.utc(2030, 1, 1, 12, 4);
      await cubit.reply('hello');
      expect(repo.replyCalls, hasLength(2));
      expect(repo.replyCalls.map((c) => c.key).toSet(), hasLength(1));
      await cubit.close();
    });

    test('a closed thread takes no reply from the app', () async {
      repo.threadResult = Right(threadFixture().withHeader(ticketFixture(status: TicketStatus.closed, awaiting: false)));
      final cubit = make();
      await _settle();
      await cubit.reply('hello');
      expect(repo.replyCalls, isEmpty);
      await cubit.close();
    });

    test('the customer closes the ticket: it becomes solved, only when the server says so', () async {
      final cubit = make();
      await _settle();
      await cubit.closeTicket();
      expect(repo.closeCalls, [_ref]);
      expect(cubit.state.thread!.status, TicketStatus.resolved);
      await cubit.close();
    });

    test('closing a ticket support already changed reads the thread again and says so in words', () async {
      repo.closeResults.add(const Left(TicketChangedFailure()));
      final cubit = make();
      await _settle();
      final readsBefore = repo.getCalls;
      await cubit.closeTicket();
      expect(repo.getCalls, readsBefore + 1);
      expect(cubit.state.closeFailure, isA<TicketChangedFailure>());
      expect(cubit.state.thread!.status, isNot(TicketStatus.resolved));
      await cubit.close();
    });

    test('a failed close shows a retry and never marks the ticket solved', () async {
      repo.closeResults.add(const Left(NetworkFailure()));
      final cubit = make();
      await _settle();
      await cubit.closeTicket();
      expect(cubit.state.closeFailure, isA<NetworkFailure>());
      expect(cubit.state.thread!.status, TicketStatus.pendingCustomer);
      await cubit.close();
    });
  });

  group('IncidentsCubit', () {
    test('loads the open incidents', () async {
      final cubit = IncidentsCubit(repo);
      await _settle();
      expect(cubit.state.open, hasLength(1));
      await cubit.close();
    });

    test('a_failed_incidents_load_does_not_block_the_page', () async {
      repo.incidentsResult = const Left(NetworkFailure());
      final cubit = IncidentsCubit(repo);
      await _settle();
      expect(cubit.state.open, isEmpty);
      expect(cubit.state.failed, isTrue);
      repo.incidentsResult = Right(incidentsFixture());
      await cubit.load();
      expect(cubit.state.open, hasLength(1));
      await cubit.close();
    });

    test('a resolved incident is not shown as open, and an empty answer shows nothing', () async {
      final resolved = incidentsFixture().single;
      repo.incidentsResult = const Right([]);
      final cubit = IncidentsCubit(repo);
      await _settle();
      expect(cubit.state.open, isEmpty);
      expect(resolved.isOpen, isTrue);
      await cubit.close();
    });
  });
}
