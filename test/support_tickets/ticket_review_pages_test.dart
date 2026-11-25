import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_message_repository.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_repository.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_message_repository.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/incidents_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/new_ticket_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/support_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/ticket_thread_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/tickets_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/new_ticket_page.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/support_page.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/ticket_thread_page.dart';
import 'package:sentech_connect_app/features/support/presentation/pages/tickets_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';

import '../helpers/pump_themed.dart';
import 'fake_support_tickets_repository.dart';

const _ref = 'TKT-7K3M9Q2A';

void main() {
  late FakeSupportTicketsRepository repo;
  final en = AppLocalizationsEn();

  setUp(() => repo = FakeSupportTicketsRepository());

  Future<TicketThreadCubit> pumpThread(WidgetTester tester) async {
    final cubit = TicketThreadCubit(repo, _ref, pending: PendingTicketKeys(), scope: 's');
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      KeyedSubtree(key: UniqueKey(), child: BlocProvider.value(value: cubit, child: TicketThreadPage(onNewTicket: () {}))),
    );
    await tester.pumpAndSettle();
    return cubit;
  }

  Future<void> pumpMessageSupportHost(WidgetTester tester, Widget child) async {
    await locator.reset();
    locator.registerLazySingleton<SupportMessageRepository>(() => MockSupportMessageRepository());
    addTearDown(locator.reset);
    await pumpThemed(tester, child);
    await tester.pumpAndSettle();
  }

  group('L1: an inline message for a refused reply', () {
    testWidgets('empty and too-long replies say so on the field', (tester) async {
      await pumpThread(tester);
      await tester.tap(find.byKey(const Key('ticket-reply-send')));
      await tester.pumpAndSettle();
      expect(find.text(en.ticketsNewIssueEmpty), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ticket-reply-field')), 'x' * 4001);
      await tester.tap(find.byKey(const Key('ticket-reply-send')));
      await tester.pumpAndSettle();
      expect(find.text(en.ticketsNewIssueTooLong(4000)), findsOneWidget);
      expect(repo.replyCalls, isEmpty);
    });
  });

  group('L4: Mark as solved waits while a reply is sending', () {
    testWidgets('the button is disabled during the send', (tester) async {
      await pumpThread(tester);
      repo.sendGate = Completer<void>();
      await tester.enterText(find.byKey(const Key('ticket-reply-field')), 'Hello');
      await tester.tap(find.byKey(const Key('ticket-reply-send')));
      await tester.pump();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('ticket-mark-solved'))).onPressed, isNull);
      repo.sendGate!.complete();
      await tester.pumpAndSettle();
      expect(tester.widget<OutlinedButton>(find.byKey(const Key('ticket-mark-solved'))).onPressed, isNotNull);
    });
  });

  group('L5: wording and the awaiting-reply cue', () {
    testWidgets('a solved ticket does not say support is waiting, in the list or the thread', (tester) async {
      final solvedWaiting = ticketFixture(status: TicketStatus.resolved, awaiting: true);
      repo.listPages[null] = Right(TicketPage(items: [solvedWaiting]));
      await pumpThemed(
        tester,
        KeyedSubtree(key: UniqueKey(), child: BlocProvider(create: (_) => TicketsCubit(repo), child: TicketsPage(onOpenTicket: (_) {}, onNewTicket: () {}))),
      );
      await tester.pumpAndSettle();
      expect(find.text(en.ticketsAwaitingReply), findsNothing);
      repo.threadResult = Right(threadFixture().withHeader(solvedWaiting));
      await pumpThread(tester);
      expect(find.text(en.ticketsAwaitingReply), findsNothing);
    });

    test('the promise lines say what is true', () {
      expect(en.ticketsUnknownOutcome, contains('while this app session lasts'));
      for (final text in [en.ticketsMarkSolvedBody, en.ticketsResolvedNote]) {
        expect(text, contains('reopen it for a few days'));
        expect(text, isNot(contains('7')));
      }
    });
  });

  group('M2: an unavailable ticket screen still offers the one-way message form', () {
    testWidgets('the list, the new ticket page and a thread each have a Message support button that opens the form', (tester) async {
      repo.listPages[null] = const Left(TicketsNotAvailableFailure());
      await pumpMessageSupportHost(
        tester,
        KeyedSubtree(key: UniqueKey(), child: BlocProvider(create: (_) => TicketsCubit(repo), child: TicketsPage(onOpenTicket: (_) {}, onNewTicket: () {}))),
      );
      expect(find.byKey(const Key('tickets-message-support')), findsOneWidget);
      expect(find.text(en.ticketsUnavailable), findsOneWidget);
      expect(en.ticketsUnavailable, isNot(contains('Help tab')));
      await tester.tap(find.byKey(const Key('tickets-message-support')));
      await tester.pumpAndSettle();
      expect(find.text(en.supportSendMessage), findsOneWidget);

      repo.categoriesResult = const Left(TicketsNotAvailableFailure());
      final cubit = NewTicketCubit(repo, pending: PendingTicketKeys(), scope: 's');
      addTearDown(cubit.close);
      await pumpMessageSupportHost(
        tester,
        KeyedSubtree(key: UniqueKey(), child: BlocProvider.value(value: cubit, child: NewTicketPage(onOpenTicket: (_) {}, onDone: () {}))),
      );
      expect(find.byKey(const Key('tickets-message-support')), findsOneWidget);

      repo.threadResult = const Left(TicketsNotAvailableFailure());
      final thread = TicketThreadCubit(repo, _ref, pending: PendingTicketKeys(), scope: 's');
      addTearDown(thread.close);
      await pumpMessageSupportHost(
        tester,
        KeyedSubtree(key: UniqueKey(), child: BlocProvider.value(value: thread, child: TicketThreadPage(onNewTicket: () {}))),
      );
      expect(find.byKey(const Key('tickets-message-support')), findsOneWidget);
    });
  });

  group('M1: the Help tab stays usable with several long incidents at large text', () {
    List<Incident> incidents() => [
      for (var i = 0; i < 3; i++)
        Incident(
          id: 'i$i',
          title: 'A long incident title number $i that keeps going to fill the line',
          severity: IncidentSeverity.degraded,
          status: IncidentStatus.identified,
          body: 'The provider wrote a long explanation of what is wrong in the area. ' * 4,
          startedAt: DateTime.utc(2026, 11, 25, 6),
          resolvedAt: null,
          updates: [IncidentUpdate(status: IncidentStatus.identified, body: 'A later update with more words. ' * 3, createdAt: DateTime.utc(2026, 11, 25, 7))],
        ),
    ];

    for (final showFaqs in [false, true]) {
      testWidgets('WhatsApp, New ticket and My tickets can all be reached (faqs: $showFaqs)', (tester) async {
        repo.incidentsResult = Right(incidents());
        var newTapped = false;
        var myTapped = false;
        await pumpThemed(
          tester,
          KeyedSubtree(
            key: UniqueKey(),
            child: MultiBlocProvider(
              providers: [
                BlocProvider(create: (_) => SupportCubit(MockSupportRepository())),
                BlocProvider(create: (_) => IncidentsCubit(repo)),
              ],
              child: SupportPage(
                showFaqs: showFaqs,
                whatsAppNumber: '+27821234567',
                onOpenTickets: () => myTapped = true,
                onNewTicket: () => newTapped = true,
              ),
            ),
          ),
          textScale: 2.0,
        );
        await tester.pumpAndSettle(const Duration(seconds: 1));
        expect(tester.takeException(), isNull);
        Future<void> reach(Key key) async {
          await tester.scrollUntilVisible(find.byKey(key), 200, scrollable: find.byType(Scrollable).first);
          await tester.ensureVisible(find.byKey(key));
          await tester.pumpAndSettle();
        }

        await reach(const Key('help-my-tickets'));
        await tester.tap(find.byKey(const Key('help-my-tickets')));
        expect(myTapped, isTrue);
        await reach(const Key('help-new-ticket'));
        await tester.tap(find.byKey(const Key('help-new-ticket')));
        expect(newTapped, isTrue);
        await tester.scrollUntilVisible(find.text(en.supportWhatsApp), -200, scrollable: find.byType(Scrollable).first);
        expect(find.text(en.supportWhatsApp), findsOneWidget);
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('M3 and L9 routing', () {
    test('a signed-out deep link to a ticket does not carry its reference into the login redirect', () {
      const signedOut = AuthState();
      final redirect = authRedirect(signedOut, Uri.parse('/support/tickets/$_ref'));
      expect(redirect, isNotNull);
      expect(redirect, isNot(contains(_ref)));
      expect(Uri.parse(redirect!).queryParameters[AppRoutes.fromParam], AppRoutes.tickets);
      expect(Uri.parse(authRedirect(signedOut, Uri.parse(AppRoutes.ticketsNew))!).queryParameters[AppRoutes.fromParam], AppRoutes.tickets);
    });
  });
}
