import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/service_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/services_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/service_detail_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/services_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/home_internet_section.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';
import 'helpers/subscriber_service_fixtures.dart';
import 'subscriber_services_cubit_test.dart' show FakeSubscriberRepository;

class _TenantRepo implements TenantRepository {
  _TenantRepo(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> _tenant(WidgetTester tester, {required bool billing}) async {
  final config = AppConfig.fromJson({
    ...fixtureMap('app_config.json'),
    'modules': {'subscriber_billing': billing},
  });
  final cubit = TenantCubit(
    repository: _TenantRepo(config),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  addTearDown(cubit.close);
  await cubit.bootstrap();
  return cubit;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  Future<void> pumpServices(WidgetTester tester, FakeSubscriberRepository repo, {Locale? locale}) async {
    final cubit = ServicesCubit(repo);
    addTearDown(cubit.close);
    await pumpThemed(
      tester,
      BlocProvider.value(value: cubit, child: const ServicesPage()),
      size: const Size(390, 1600),
    );
    await tester.pumpAndSettle();
  }

  group('services list', () {
    testWidgets('loading shows a spinner', (tester) async {
      final gate = Completer<void>();
      final cubit = ServicesCubit(FakeSubscriberRepository()..gate = gate);
      addTearDown(cubit.close);
      await pumpThemed(tester, BlocProvider.value(value: cubit, child: const ServicesPage()));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });

    testWidgets('empty state', (tester) async {
      await pumpServices(tester, FakeSubscriberRepository());
      expect(find.text('You have no home internet service yet'), findsOneWidget);
    });

    testWidgets('error shows retry; retry reloads', (tester) async {
      final repo = FakeSubscriberRepository(failure: const ServerFailure());
      await pumpServices(tester, repo);
      expect(find.text('Retry'), findsOneWidget);
      repo
        ..failure = null
        ..services = [testService()];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Home Hotspot 10'), findsOneWidget);
    });

    testWidgets('offline uses the offline wording', (tester) async {
      await pumpServices(tester, FakeSubscriberRepository(failure: const NetworkFailure()));
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
    });

    testWidgets('cards: status, price, paid-until, banners; ended ones under Past services', (tester) async {
      await pumpServices(
        tester,
        FakeSubscriberRepository(
          services: [
            testService(
              id: 'p',
              planName: 'Home Air 50',
              kind: SubscriberPlanKind.fixedWireless,
              status: ServiceStatus.pending,
              activationBlocker: ActivationBlocker.firstInvoiceUnpaid,
              priceCents: 59900,
            ),
            testService(
              id: 'a',
              paidThrough: DateTime.utc(2026, 11, 30),
              cancelEffectiveOn: DateTime.utc(2026, 11, 30),
              pendingPlanId: 'p5',
              pendingPlanName: 'Home Hotspot 5',
              planChangeOn: DateTime.utc(2026, 11, 1),
            ),
            testService(id: 's', planName: 'Suspended one', status: ServiceStatus.suspended, suspendReason: SuspendReason.nonPayment),
            testService(
              id: 'c',
              planName: 'Old plan',
              status: ServiceStatus.cancelled,
              cancelEffectiveOn: DateTime.utc(2026, 8, 31),
            ),
          ],
        ),
      );
      expect(find.text('Pay your first invoice to start'), findsOneWidget);
      expect(find.text('Starting'), findsOneWidget);
      expect(find.text('Fixed wireless · R599.00 a month'), findsOneWidget);
      expect(find.text('Paid until Nov 30, 2026'), findsOneWidget);
      expect(find.text('Cancellation scheduled'), findsOneWidget);
      expect(find.text('Ends on Nov 30, 2026'), findsOneWidget);
      expect(find.text('Plan change to Home Hotspot 5 on Nov 1, 2026'), findsOneWidget);
      expect(find.text('Pay your open invoice to restore service'), findsOneWidget);
      expect(find.text('Past services'), findsOneWidget);
      expect(find.text('Ended on Aug 31, 2026'), findsOneWidget);
      // Invoices/ID check are not registered yet: no button inside cards or banners.
      expect(find.text('View invoices'), findsNothing);
    });

    testWidgets('pull to refresh reloads', (tester) async {
      final repo = FakeSubscriberRepository(services: [testService()]);
      await pumpServices(tester, repo);
      repo.services = [testService(planName: 'Renamed')];
      await tester.fling(find.byType(ListView), const Offset(0, 400), 1000);
      await tester.pumpAndSettle();
      expect(find.text('Renamed'), findsOneWidget);
    });
  });

  group('service detail', () {
    Future<void> pumpDetail(WidgetTester tester, FakeSubscriberRepository repo, String id) async {
      final cubit = ServiceDetailCubit(repo, id);
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(value: cubit, child: const ServiceDetailPage()),
        size: const Size(390, 1200),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows plan facts and the generic pending copy for an unknown blocker', (tester) async {
      await pumpDetail(
        tester,
        FakeSubscriberRepository(
          services: [testService(status: ServiceStatus.pending, activationBlocker: ActivationBlocker.unknown)],
        ),
        'svc-1',
      );
      expect(find.text('Home Hotspot 10'), findsOneWidget);
      expect(find.text('Home hotspot'), findsOneWidget);
      expect(find.text('R199.00 a month'), findsOneWidget);
      expect(find.text('Down 10 Mbps, up 5 Mbps'), findsOneWidget);
      expect(find.text('SV-000101'), findsOneWidget);
      expect(find.text('Activating, this can take a few minutes. Pull to refresh.'), findsOneWidget);
    });

    testWidgets('suspended for ID check, ended service, and a missing service', (tester) async {
      await pumpDetail(
        tester,
        FakeSubscriberRepository(services: [testService(status: ServiceStatus.suspended, suspendReason: SuspendReason.kyc)]),
        'svc-1',
      );
      expect(find.text('We need to check your ID before service can resume'), findsOneWidget);

      await pumpDetail(
        tester,
        FakeSubscriberRepository(
          services: [testService(status: ServiceStatus.cancelled, cancelEffectiveOn: DateTime.utc(2026, 8, 31))],
        ),
        'svc-1',
      );
      expect(find.text('Ended'), findsWidgets);
      expect(find.text('Ended on Aug 31, 2026'), findsOneWidget);

      await pumpDetail(tester, FakeSubscriberRepository(), 'nope');
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('no action buttons for change plan or cancel (later slices)', (tester) async {
      await pumpDetail(tester, FakeSubscriberRepository(services: [testService()]), 'svc-1');
      expect(find.byType(FilledButton), findsNothing);
      expect(find.byType(ElevatedButton), findsNothing);
    });
  });

  group('Account "Home internet" section', () {
    Future<void> pumpSection(WidgetTester tester, TenantCubit? tenant) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(body: ListView(children: const [HomeInternetSection()])),
          ),
          GoRoute(path: '/services', builder: (_, _) => const Scaffold(body: Text('SERVICES SCREEN'))),
        ],
      );
      addTearDown(router.dispose);
      final app = MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
      await tester.pumpWidget(tenant == null ? app : BlocProvider.value(value: tenant, child: app));
      await tester.pumpAndSettle();
    }

    testWidgets('module off: absent', (tester) async {
      await pumpSection(tester, await _tenant(tester, billing: false));
      expect(find.text('Home internet'), findsNothing);
      expect(find.text('My services'), findsNothing);
    });

    testWidgets('no tenant loaded: absent', (tester) async {
      await pumpSection(tester, null);
      expect(find.text('My services'), findsNothing);
    });

    testWidgets('module on: My services row opens the services route', (tester) async {
      await pumpSection(tester, await _tenant(tester, billing: true));
      expect(find.text('Home internet'), findsOneWidget);
      expect(find.text('My services'), findsOneWidget);
      // The Invoices row arrived with S2; the ID check row arrives with S4.
      expect(find.text('Invoices'), findsOneWidget);
      await tester.tap(find.text('My services'));
      await tester.pumpAndSettle();
      expect(find.text('SERVICES SCREEN'), findsOneWidget);
    });

    test('registry: services and invoices registered, kyc not yet', () {
      expect(subscriberEntryRegistered('/services'), isTrue);
      expect(subscriberEntryRegistered('/invoices'), isTrue);
      expect(subscriberEntryRegistered('/kyc'), isFalse);
    });
  });
}
