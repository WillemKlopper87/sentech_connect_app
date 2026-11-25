import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/new_ticket_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/keyed_attempt.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/ticket_thread_cubit.dart';

import 'fake_support_tickets_repository.dart';

Future<void> _settle() => Future<void>.delayed(Duration.zero);

String Function() _keys() {
  var n = 0;
  return () => 'key-${++n}-0000000';
}

const _ref = 'TKT-7K3M9Q2A';

void main() {
  late FakeSupportTicketsRepository repo;

  setUp(() => repo = FakeSupportTicketsRepository());

  NewTicketCubit makeNew() => NewTicketCubit(repo, newKey: _keys(), pending: PendingTicketKeys(), scope: 's');
  TicketThreadCubit makeThread({DateTime Function()? now}) => TicketThreadCubit(
    repo,
    _ref,
    newKey: _keys(),
    pending: PendingTicketKeys(),
    scope: 's',
    now: now ?? () => DateTime.utc(2026, 11, 22, 10),
  );

  group('M4: the check before a changed text counts only when the read succeeded', () {
    test('new ticket: a failed list read does not acknowledge, keeps the unknown notice and sends nothing', () async {
      repo.createResults.addAll([const Left(NetworkFailure()), const Right('TKT-2B8D4F6H')]);
      final cubit = makeNew();
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: 'First');
      repo.listPages[null] = const Left(NetworkFailure());
      await cubit.submit(categoryKey: 'billing', body: 'Second');
      expect(cubit.state.notice, NewTicketNotice.unknownOutcome);
      expect(repo.createCalls, hasLength(1));
      // The second tap checks again (the first check failed); it still sends nothing.
      await cubit.submit(categoryKey: 'billing', body: 'Second');
      expect(repo.listCursors, [null, null]);
      expect(repo.createCalls, hasLength(1));
      // Once the read works the customer sees the tickets; only the NEXT tap sends, under a new key.
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()]));
      await cubit.submit(categoryKey: 'billing', body: 'Second');
      expect(cubit.state.notice, NewTicketNotice.checkFirst);
      expect(repo.createCalls, hasLength(1));
      await cubit.submit(categoryKey: 'billing', body: 'Second');
      expect(repo.createCalls, hasLength(2));
      expect(repo.createCalls.last.key, isNot(repo.createCalls.first.key));
      await cubit.close();
    });

    test('reply: a failed thread read does not acknowledge either', () async {
      repo.replyResults.addAll([const Left(NetworkFailure()), Right(ticketFixture(awaiting: false, status: TicketStatus.open))]);
      final cubit = makeThread();
      await _settle();
      await cubit.reply('first');
      repo.threadResult = const Left(NetworkFailure());
      await cubit.reply('second');
      expect(cubit.state.notice, ReplyNotice.unknownOutcome);
      expect(repo.replyCalls, hasLength(1));
      await cubit.reply('second');
      expect(repo.replyCalls, hasLength(1), reason: 'still not acknowledged: nothing is sent under a new key');
      repo.threadResult = Right(threadFixture());
      await cubit.reply('second');
      expect(cubit.state.notice, ReplyNotice.checkFirst);
      await cubit.reply('second');
      expect(repo.replyCalls, hasLength(2));
      expect(repo.replyCalls.last.key, isNot(repo.replyCalls.first.key));
      await cubit.close();
    });
  });

  group('L1: the length is counted in code points, as the server does', () {
    test('new ticket: 4000 emoji are allowed, 4001 are not, even though they are 8000 UTF-16 units', () async {
      final cubit = makeNew();
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: '\u{1F600}' * 4000);
      expect(cubit.state.issue, isNull);
      expect(repo.createCalls, hasLength(1));
      final other = makeNew();
      await _settle();
      await other.submit(categoryKey: 'billing', body: '\u{1F600}' * 4001);
      expect(other.state.issue, NewTicketIssue.bodyTooLong);
      await cubit.close();
      await other.close();
    });

    test('reply: empty and too-long text give an inline issue, not a silent no-op', () async {
      final cubit = makeThread();
      await _settle();
      await cubit.reply('   ');
      expect(cubit.state.replyIssue, ReplyIssue.empty);
      await cubit.reply('\u{1F600}' * 4001);
      expect(cubit.state.replyIssue, ReplyIssue.tooLong);
      expect(repo.replyCalls, isEmpty);
      await cubit.reply('\u{1F600}' * 4000);
      expect(cubit.state.replyIssue, isNull);
      expect(repo.replyCalls, hasLength(1));
      await cubit.close();
    });
  });

  group('L2/L3: the sent reply is on screen exactly once', () {
    test('it is appended to the CURRENT thread even when a read started meanwhile, and kept if the follow-up read fails', () async {
      final cubit = makeThread();
      await _settle();
      repo.threadResult = const Left(NetworkFailure());
      final gate = Completer<void>();
      repo.getGate = gate;
      unawaited(cubit.refresh());
      await _settle();
      repo.getGate = null;
      await cubit.reply('Sent now');
      await _settle();
      gate.complete();
      await _settle();
      expect(cubit.state.thread!.messages.where((m) => m.body == 'Sent now'), hasLength(1));
      await cubit.close();
    });

    test('a read that already shows the reply does not get a second bubble', () async {
      final cubit = makeThread();
      await _settle();
      final withReply = threadFixture().withMessages([
        ...threadFixture().messages,
        TicketMessage(author: TicketAuthor.you, body: 'Sent now', createdAt: DateTime.utc(2026, 11, 22, 10)),
      ]);
      repo.sendGate = Completer<void>();
      unawaited(cubit.reply('Sent now'));
      await _settle();
      repo.threadResult = Right(withReply);
      await cubit.refresh(); // shows the reply before the send answers
      repo.sendGate!.complete();
      await _settle();
      await _settle();
      expect(cubit.state.thread!.messages.where((m) => m.body == 'Sent now'), hasLength(1));
      await cubit.close();
    });

    test('a replayed reply (retry after an unknown outcome that had in fact arrived) shows once', () async {
      final cubit = makeThread();
      await _settle();
      repo.replyResults.addAll([const Left(NetworkFailure()), Right(ticketFixture(awaiting: false, status: TicketStatus.open))]);
      await cubit.reply('Hello again');
      // The first attempt had arrived: the thread read shows it.
      repo.threadResult = Right(
        threadFixture().withMessages([
          ...threadFixture().messages,
          TicketMessage(author: TicketAuthor.you, body: 'Hello again', createdAt: DateTime.utc(2026, 11, 22, 10)),
        ]),
      );
      await cubit.refresh();
      await cubit.reply('Hello again');
      await _settle();
      expect(repo.replyCalls.map((c) => c.key).toSet(), hasLength(1));
      expect(cubit.state.thread!.messages.where((m) => m.body == 'Hello again'), hasLength(1));
      await cubit.close();
    });
  });

  group('L6: a 429 settles the attempt', () {
    test('a changed text after a 429 needs no check and goes under a new key', () async {
      var now = DateTime.utc(2030, 1, 1, 12);
      repo.createResults.addAll([const Left(RateLimitedFailure('slow', Duration(seconds: 30))), const Right(_ref)]);
      final cubit = NewTicketCubit(repo, newKey: _keys(), pending: PendingTicketKeys(), scope: 's', now: () => now);
      await _settle();
      await cubit.submit(categoryKey: 'billing', body: 'First');
      now = now.add(const Duration(minutes: 1));
      await cubit.submit(categoryKey: 'billing', body: 'Changed');
      expect(repo.listCursors, isEmpty, reason: 'no list check after a 429');
      expect(repo.createCalls, hasLength(2));
      expect(repo.createCalls.last.body, 'Changed');
      await cubit.close();
    });
  });

  group('L8', () {
    test('KeyedAttempt.hasUnknown follows the holder', () {
      final holder = PendingTicketKeys();
      final attempt = KeyedAttempt(pending: holder, scope: 's', newKey: _keys());
      expect(attempt.hasUnknown, isFalse);
      attempt.begin(1);
      expect(attempt.hasUnknown, isTrue);
      attempt.settle();
      expect(attempt.hasUnknown, isFalse);
    });

    test('SupportCubit emits nothing after it is closed while the FAQs load', () async {
      final cubit = SupportCubit(MockSupportRepository());
      final emitted = <Object>[];
      final sub = cubit.stream.listen(emitted.add);
      await cubit.close();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(emitted, isEmpty);
      await sub.cancel();
    });
  });
}
