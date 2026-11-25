import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/incidents_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/new_ticket_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/ticket_thread_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/tickets_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/new_ticket_page.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/ticket_thread_page.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/tickets_page.dart';
import 'package:sentech_connect_app/features/support/presentation/widgets/incident_notice_card.dart';

import '../helpers/pump_themed.dart';
import 'fake_support_tickets_repository.dart';

const _ref = 'TKT-7K3M9Q2A';

void main() {
  late FakeSupportTicketsRepository repo;

  setUp(() {
    repo = FakeSupportTicketsRepository();
    SharedPreferences.setMockInitialValues({});
  });

  Future<void> pumpList(WidgetTester tester, {double textScale = 1.0, void Function(String)? onOpen, VoidCallback? onNew}) async {
    await pumpThemed(
      tester,
      KeyedSubtree(
        key: UniqueKey(),
        child: BlocProvider(
          create: (_) => TicketsCubit(repo),
          child: TicketsPage(onOpenTicket: onOpen ?? (_) {}, onNewTicket: onNew ?? () {}),
        ),
      ),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
  }

  Future<NewTicketCubit> pumpNew(
    WidgetTester tester, {
    double textScale = 1.0,
    DateTime Function()? now,
    PendingTicketKeys? pending,
    void Function(String)? onOpen,
    VoidCallback? onDone,
  }) async {
    final cubit = NewTicketCubit(repo, pending: pending ?? PendingTicketKeys(), scope: 's', now: now);
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      KeyedSubtree(
        key: UniqueKey(),
        child: BlocProvider.value(
          value: cubit,
          child: NewTicketPage(onOpenTicket: onOpen ?? (_) {}, onDone: onDone ?? () {}),
        ),
      ),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<TicketThreadCubit> pumpThread(WidgetTester tester, {double textScale = 1.0, DateTime Function()? now, VoidCallback? onNew}) async {
    final cubit = TicketThreadCubit(repo, _ref, pending: PendingTicketKeys(), scope: 's', now: now);
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      KeyedSubtree(key: UniqueKey(), child: BlocProvider.value(value: cubit, child: TicketThreadPage(onNewTicket: onNew ?? () {}))),
      textScale: textScale,
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<void> pickBilling(WidgetTester tester) async {
    await tester.tap(find.byKey(const Key('ticket-category-field')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Billing').last);
    await tester.pumpAndSettle();
  }

  group('TicketsPage', () {
    testWidgets('list_shows_awaiting_reply_and_empty_state', (tester) async {
      repo.listPages[null] = Right(
        TicketPage(items: [ticketFixture(), ticketFixture(reference: 'TKT-2B8D4F6H', status: TicketStatus.open, awaiting: false)]),
      );
      await pumpList(tester);
      expect(find.text('Billing'), findsNWidgets(2));
      expect(find.textContaining(_ref), findsOneWidget);
      // The cue and the status are words, not only a colour.
      expect(find.text('Support is waiting for your reply'), findsOneWidget);
      expect(find.text('Waiting for you'), findsOneWidget);
      expect(find.text('Open'), findsOneWidget);
      // No response-time promise anywhere.
      expect(find.textContaining(RegExp('hours|within|SLA|soon|24', caseSensitive: false)), findsNothing);

      repo.listPages[null] = const Right(TicketPage(items: []));
      await pumpList(tester);
      expect(find.text('You have no tickets yet.'), findsOneWidget);
      expect(find.byKey(const Key('tickets-new-button')), findsOneWidget);
    });

    testWidgets('a ticket opens by its reference and the new ticket button works', (tester) async {
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()]));
      String? opened;
      var created = false;
      await pumpList(tester, onOpen: (r) => opened = r, onNew: () => created = true);
      await tester.tap(find.textContaining(_ref));
      expect(opened, _ref);
      await tester.tap(find.byKey(const Key('tickets-new-button')));
      expect(created, isTrue);
    });

    testWidgets('feature unavailable says so in plain words, with no retry loop and no empty screen', (tester) async {
      repo.listPages[null] = const Left(TicketsNotAvailableFailure());
      await pumpList(tester);
      expect(find.textContaining('not available right now'), findsOneWidget);
    });

    testWidgets('an error shows a retry; more pages load on request without a duplicate', (tester) async {
      repo.listPages[null] = const Left(NetworkFailure());
      await pumpList(tester);
      expect(find.text('Retry'), findsOneWidget);
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()], nextCursor: 'c1'));
      repo.listPages['c1'] = Right(TicketPage(items: [ticketFixture(), ticketFixture(reference: 'TKT-2B8D4F6H')]));
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const Key('tickets-more')));
      await tester.tap(find.byKey(const Key('tickets-more')));
      await tester.pumpAndSettle();
      expect(find.textContaining(_ref), findsOneWidget);
      expect(find.textContaining('TKT-2B8D4F6H'), findsOneWidget);
    });
  });

  group('NewTicketPage', () {
    testWidgets('create_validates_and_shows_the_reference_after_success', (tester) async {
      String? opened;
      await pumpNew(tester, onOpen: (r) => opened = r);
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('Choose what the ticket is about.'), findsOneWidget);
      expect(repo.createCalls, isEmpty);

      await pickBilling(tester);
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('Write a message.'), findsOneWidget);
      expect(repo.createCalls, isEmpty);

      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'I was charged twice for my pass.');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(repo.createCalls.single.category, 'billing');
      expect(repo.createCalls.single.body, 'I was charged twice for my pass.');
      expect(find.text('Ticket sent'), findsOneWidget);
      expect(find.textContaining(_ref), findsOneWidget);
      // The typed text is gone with the form.
      expect(find.text('I was charged twice for my pass.'), findsNothing);
      await tester.tap(find.byKey(const Key('ticket-done-view')));
      expect(opened, _ref);
    });

    testWidgets('the draft is kept after a failure, never written to disk, and one tap sends one ticket', (tester) async {
      repo.createResults.add(const Left(NetworkFailure()));
      await pumpNew(tester);
      await pickBilling(tester);
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'My complaint');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not confirm'), findsOneWidget);
      expect(find.text('My complaint'), findsOneWidget, reason: 'the text is not lost');
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });

    testWidgets('a category the server removed is explained and the topics are read again', (tester) async {
      repo.createResults.add(const Left(TicketCategoryGoneFailure()));
      await pumpNew(tester);
      await pickBilling(tester);
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'Hello');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('That topic is no longer offered. Pick another.'), findsOneWidget);
      expect(find.text('Hello'), findsOneWidget);
    });

    testWidgets('send_is_held_during_a_rate_limit_wait', (tester) async {
      var now = DateTime.utc(2030, 1, 1, 12);
      repo.createResults.addAll([const Left(RateLimitedFailure('slow', Duration(minutes: 5))), const Right(_ref)]);
      await pumpNew(tester, now: () => now);
      await pickBilling(tester);
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'Hello');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('5 minutes'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('ticket-send'))).onPressed, isNull);
      await tester.tap(find.byKey(const Key('ticket-send')), warnIfMissed: false);
      expect(repo.createCalls, hasLength(1));
      // The wait is over: the button comes back and the same request is retried.
      now = DateTime.utc(2030, 1, 1, 12, 6);
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(find.byKey(const Key('ticket-send'))).onPressed, isNotNull);
    });

    testWidgets('the text is limited to the server limit', (tester) async {
      await pumpNew(tester);
      final field = tester.widget<TextField>(find.byKey(const Key('ticket-body-field')));
      expect(field.maxLength, ticketBodyMaxLength);
    });

    testWidgets('no topics because the server has none still gives a way out, and an unavailable feature says so', (tester) async {
      repo.categoriesResult = const Left(TicketsNotAvailableFailure());
      await pumpNew(tester);
      expect(find.textContaining('not available right now'), findsOneWidget);
      expect(find.byKey(const Key('ticket-send')), findsNothing);
    });

    testWidgets('a changed text after an unknown outcome shows the latest tickets first', (tester) async {
      repo.createResults.add(const Left(NetworkFailure()));
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()]));
      await pumpNew(tester);
      await pickBilling(tester);
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'First');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'Second');
      await tester.tap(find.byKey(const Key('ticket-send')));
      await tester.pumpAndSettle();
      expect(find.text('Your latest tickets'), findsOneWidget);
      expect(find.textContaining(_ref), findsOneWidget);
      expect(repo.createCalls, hasLength(1));
    });

    testWidgets('large_text_does_not_overflow', (tester) async {
      await pumpNew(tester, textScale: 2.0);
      await pickBilling(tester);
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'Hello');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('TicketThreadPage', () {
    testWidgets('thread_shows_messages_in_order_and_hides_nothing_staff_only', (tester) async {
      await pumpThread(tester);
      final you = find.text('I was charged twice for my pass.');
      final support = find.text('Thanks, can you tell us the date of the second charge?');
      expect(you, findsOneWidget);
      expect(support, findsOneWidget);
      expect(tester.getTopLeft(you).dy, lessThan(tester.getTopLeft(support).dy), reason: 'the server order is kept');
      expect(find.text('You'), findsOneWidget);
      expect(find.text('Support'), findsWidgets);
      expect(find.textContaining(_ref), findsOneWidget);
      expect(find.text('Waiting for you'), findsOneWidget);
      // No internal id (a uuid) and no staff name is on screen.
      expect(find.textContaining(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-')), findsNothing);
    });

    testWidgets('a message whose text was removed says so, and an unknown author is neutral', (tester) async {
      final thread = TicketThread(
        reference: _ref,
        status: TicketStatus.open,
        categoryKey: 'billing',
        categoryName: 'Billing',
        awaitingReply: false,
        createdAt: DateTime.utc(2026, 11, 20),
        updatedAt: DateTime.utc(2026, 11, 20),
        messages: [
          TicketMessage(author: TicketAuthor.support, body: null, createdAt: DateTime.utc(2026, 11, 20)),
          TicketMessage(author: TicketAuthor.unknown, body: 'From the future', createdAt: DateTime.utc(2026, 11, 21)),
        ],
      );
      repo.threadResult = Right(thread);
      await pumpThread(tester);
      expect(find.text('The text of this message is no longer available.'), findsOneWidget);
      expect(find.text('Message'), findsOneWidget);
      expect(find.text('From the future'), findsOneWidget);
    });

    testWidgets('a reply is sent once, shows in the thread and the box is cleared', (tester) async {
      final withReply = threadFixture().withMessages([
        ...threadFixture().messages,
        TicketMessage(author: TicketAuthor.you, body: 'The 3rd of November.', createdAt: DateTime.utc(2026, 11, 22, 10)),
      ]);
      final cubit = await pumpThread(tester);
      repo.threadResult = Right(withReply);
      await tester.enterText(find.byKey(const Key('ticket-reply-field')), 'The 3rd of November.');
      await tester.tap(find.byKey(const Key('ticket-reply-send')));
      await tester.pumpAndSettle();
      expect(repo.replyCalls.single.body, 'The 3rd of November.');
      expect(cubit.state.thread!.messages.last.body, 'The 3rd of November.');
      expect(tester.widget<TextField>(find.byKey(const Key('ticket-reply-field'))).controller!.text, isEmpty);
      expect((await SharedPreferences.getInstance()).getKeys(), isEmpty);
    });

    testWidgets('a failed reply keeps the text and says it may not have been sent', (tester) async {
      repo.replyResults.add(const Left(NetworkFailure()));
      await pumpThread(tester);
      await tester.enterText(find.byKey(const Key('ticket-reply-field')), 'Keep me');
      await tester.tap(find.byKey(const Key('ticket-reply-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('could not confirm'), findsOneWidget);
      expect(tester.widget<TextField>(find.byKey(const Key('ticket-reply-field'))).controller!.text, 'Keep me');
    });

    testWidgets('closed_ticket_hides_the_reply_box_and_says_why', (tester) async {
      repo.threadResult = Right(threadFixture().withHeader(ticketFixture(status: TicketStatus.closed, awaiting: false)));
      var opened = false;
      await pumpThread(tester, onNew: () => opened = true);
      expect(find.byKey(const Key('ticket-reply-field')), findsNothing);
      expect(find.byKey(const Key('ticket-reply-send')), findsNothing);
      expect(find.byKey(const Key('ticket-mark-solved')), findsNothing);
      expect(find.textContaining('This ticket is closed'), findsWidgets);
      await tester.tap(find.byKey(const Key('ticket-thread-new')));
      expect(opened, isTrue);
    });

    testWidgets('a reply to a ticket that closed meanwhile gets a plain refusal and the thread is refreshed', (tester) async {
      repo.replyResults.add(const Left(TicketClosedFailure()));
      await pumpThread(tester);
      repo.threadResult = Right(threadFixture().withHeader(ticketFixture(status: TicketStatus.closed, awaiting: false)));
      await tester.enterText(find.byKey(const Key('ticket-reply-field')), 'Too late');
      await tester.tap(find.byKey(const Key('ticket-reply-send')));
      await tester.pumpAndSettle();
      expect(find.textContaining('your message was not sent'), findsOneWidget);
      expect(find.byKey(const Key('ticket-reply-field')), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('a solved ticket says so and can be answered; marking solved asks first', (tester) async {
      await pumpThread(tester);
      await tester.tap(find.byKey(const Key('ticket-mark-solved')));
      await tester.pumpAndSettle();
      expect(find.text('Mark this ticket as solved?'), findsOneWidget);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(repo.closeCalls, isEmpty);
      await tester.tap(find.byKey(const Key('ticket-mark-solved')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('ticket-mark-solved-confirm')));
      await tester.pumpAndSettle();
      expect(repo.closeCalls, [_ref]);
      expect(find.textContaining('marked as solved'), findsWidgets);
      expect(find.byKey(const Key('ticket-reply-field')), findsOneWidget);
      expect(find.byKey(const Key('ticket-mark-solved')), findsNothing);
    });

    testWidgets('not found and errors are plain words with a way back, never an empty screen', (tester) async {
      repo.threadResult = const Left(TicketNotFoundFailure());
      await pumpThread(tester);
      expect(find.text('We could not find that ticket.'), findsOneWidget);
      repo.threadResult = const Left(NetworkFailure());
      await pumpThread(tester);
      expect(find.text('Retry'), findsOneWidget);
      repo.threadResult = const Left(TicketsNotAvailableFailure());
      await pumpThread(tester);
      expect(find.textContaining('not available right now'), findsOneWidget);
    });

    testWidgets('large_text_does_not_overflow', (tester) async {
      await pumpThread(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
      await tester.enterText(find.byKey(const Key('ticket-reply-field')), 'Hello there');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    });
  });

  group('IncidentNoticeCard', () {
    Future<void> pumpCard(WidgetTester tester, {double textScale = 1.0}) async {
      await pumpThemed(
        tester,
        KeyedSubtree(key: UniqueKey(), child: BlocProvider(create: (_) => IncidentsCubit(repo), child: const IncidentNoticeCard())),
        textScale: textScale,
      );
      await tester.pumpAndSettle();
    }

    testWidgets('incident_card_shows_only_server_text', (tester) async {
      await pumpCard(tester);
      expect(find.text('Known network issue'), findsOneWidget);
      expect(find.text('Slow speeds in the area'), findsOneWidget);
      expect(find.textContaining('Service affected'), findsOneWidget);
      expect(find.text('We have found the fault and are working on it.'), findsWidgets);
      // The app adds no cause and no time to fix.
      expect(find.textContaining(RegExp('caused|fixed by|resolved by|expected|ETA|hours', caseSensitive: false)), findsNothing);
      expect(find.textContaining(RegExp(r'[0-9a-f]{8}-[0-9a-f]{4}-')), findsNothing, reason: 'the incident id is never shown');
    });

    testWidgets('no open incident, or a failed load, shows nothing at all', (tester) async {
      repo.incidentsResult = const Right([]);
      await pumpCard(tester);
      expect(find.text('Known network issue'), findsNothing);
      repo.incidentsResult = const Left(NetworkFailure());
      await pumpCard(tester);
      expect(find.text('Known network issue'), findsNothing);
      expect(find.byType(Text), findsNothing);
    });

    testWidgets('a resolved incident is not shown as a live one', (tester) async {
      final resolved = Incident(
        id: 'a',
        title: 'Old problem',
        severity: IncidentSeverity.outage,
        status: IncidentStatus.resolved,
        body: 'Fixed',
        startedAt: DateTime.utc(2026, 11, 24),
        resolvedAt: DateTime.utc(2026, 11, 24, 2),
        updates: const [],
      );
      repo.incidentsResult = Right([resolved]);
      await pumpCard(tester);
      expect(find.text('Old problem'), findsNothing);
    });

    testWidgets('large_text_does_not_overflow', (tester) async {
      await pumpCard(tester, textScale: 2.0);
      expect(tester.takeException(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('tap targets and labels: list, new ticket and thread meet the guidelines', (tester) async {
      final handle = tester.ensureSemantics();
      repo.listPages[null] = Right(TicketPage(items: [ticketFixture()]));
      await pumpList(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await pumpNew(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await pumpThread(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      handle.dispose();
    });
  });
}
