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
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/pages/dashboard_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/mock_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/home/home_overview_cubit.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'helpers/subscriber_service_fixtures.dart';

class _Subs implements SubscriberRepository {
  List<SubscriberService> services = [];
  Failure? failure;
  int calls = 0;
  @override
  Future<Either<Failure, SubscriberAccount?>> getAccount() async => const Right(null);
  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async {
    calls++;
    return failure != null ? Left(failure!) : Right(services);
  }

  @override
  Future<Either<Failure, SubscriberService>> getService(String id) async => Right(services.first);

  // The dashboard never changes or cancels a plan.
  @override
  Future<Either<Failure, SubscriberSignup>> signup({
    required String planId,
    required String termsVersion,
    required String idempotencyKey,
    String? installAddress,
  }) async => throw UnimplementedError('signup');

  @override
  Future<Either<Failure, PlanChange>> changePlan(String serviceId, String newPlanId, {required String idempotencyKey}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, SubscriberService>> cancel(String serviceId, String reason, {required String idempotencyKey}) =>
      throw UnimplementedError();
}

class _SlowSubs extends _Subs {
  _SlowSubs(this.gate);
  final Future<void> gate;
  @override
  Future<Either<Failure, List<SubscriberService>>> listServices() async {
    await gate;
    return super.listServices();
  }
}

class _Invoices implements InvoiceRepository {
  List<SubscriberInvoice> open = [];
  Failure? failure;
  int calls = 0;
  bool? lastOpenOnly;
  @override
  Future<Either<Failure, List<SubscriberInvoice>>> list({bool openOnly = false}) async {
    calls++;
    lastOpenOnly = openOnly;
    return failure != null ? Left(failure!) : Right(open);
  }

  @override
  Future<Either<Failure, SubscriberInvoice>> get(String id) async => Right(open.first);
  @override
  Future<Either<Failure, PaymentHandoff>> startCheckout(String id, {required String idempotencyKey}) =>
      throw UnimplementedError();
}

class _Kyc implements KycRepository {
  KycRecord? record;
  Failure? failure;
  int calls = 0;
  @override
  Future<Either<Failure, KycRecord?>> getStatus() async {
    calls++;
    return failure != null ? Left(failure!) : Right(record);
  }

  @override
  Future<Either<Failure, KycRecord>> submit(KycSubmission submission, {required String idempotencyKey}) =>
      throw UnimplementedError();
}

SubscriberInvoice _invoice({String id = 'inv-1', int amount = 29900, int paid = 0}) => SubscriberInvoice(
  id: id,
  serviceId: 'svc-1',
  invoiceNo: 'INV-$id',
  kind: 'recurring',
  status: InvoiceStatus.open,
  periodStart: DateTime.utc(2026, 12),
  periodEnd: DateTime.utc(2026, 12, 31),
  issueDate: DateTime.utc(2026, 11, 25),
  dueDate: DateTime.utc(2026, 12, 1),
  amountCents: amount,
  vatCents: 0,
  amountPaidCents: paid,
);

KycRecord _kycRecord(KycStatus status) => KycRecord(
  status: status,
  idType: KycIdType.saId,
  idNumberLast4: '1234',
  consentVersion: '2026-01-01',
  consentAt: DateTime.utc(2026, 10, 1),
);

class _TenantRepo implements TenantRepository {
  _TenantRepo(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> _tenant({required bool billing}) async {
  final config = AppConfig.fromJson({
    ...fixtureMap('app_config.json'),
    'modules': {'subscriber_billing': billing},
  });
  final cubit = TenantCubit(
    repository: _TenantRepo(config),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  await cubit.bootstrap();
  return cubit;
}

void main() {
  setUpAll(() => initializeDateFormatting('en'));

  final pushed = <String>[];
  late _Subs subs;
  late _Invoices invoices;
  late _Kyc kyc;

  setUp(() {
    pushed.clear();
    subs = _Subs();
    invoices = _Invoices();
    kyc = _Kyc();
  });

  group('HomeOverviewCubit', () {
    HomeOverviewCubit make() => HomeOverviewCubit(subs, invoices, kyc);

    test('loads the three sources, asks for open invoices only, drops cancelled services', () async {
      subs.services = [testService(id: 'a'), testService(id: 'b', status: ServiceStatus.cancelled)];
      invoices.open = [_invoice()];
      kyc.record = _kycRecord(KycStatus.pending);
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.services.data!.map((s) => s.id), ['a']);
      expect(cubit.state.openInvoices.data, hasLength(1));
      expect(cubit.state.kyc.data?.status, KycStatus.pending);
      expect(invoices.lastOpenOnly, isTrue);
    });

    test('one failing source does not touch the others', () async {
      subs.failure = const NetworkFailure();
      invoices.open = [_invoice()];
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.services.load, HomeLoad.failure);
      expect(cubit.state.openInvoices.load, HomeLoad.loaded);
      expect(cubit.state.kyc.load, HomeLoad.loaded);
    });

    test('ensureLoaded loads once; load refreshes', () async {
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.ensureLoaded();
      await cubit.ensureLoaded();
      expect(subs.calls, 1);
      await cubit.load();
      expect(subs.calls, 2);
    });

    test('a failed refresh keeps the data already loaded', () async {
      subs.services = [testService()];
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.load();
      subs.failure = const NetworkFailure();
      await cubit.load();
      expect(cubit.state.services.load, HomeLoad.loaded);
      expect(cubit.state.services.data, hasLength(1));
    });

    test('a failed section can be retried on its own', () async {
      invoices.failure = const ServerFailure();
      final cubit = make();
      addTearDown(cubit.close);
      await cubit.load();
      expect(cubit.state.openInvoices.load, HomeLoad.failure);
      invoices.failure = null;
      invoices.open = [_invoice()];
      final before = subs.calls;
      await cubit.loadInvoices();
      expect(cubit.state.openInvoices.data, hasLength(1));
      expect(subs.calls, before);
    });
  });

  group('Home dashboard subscriber sections', () {
    /// [billing] null = no tenant above (module state unknown, like most tests).
    Future<void> pump(WidgetTester tester, {bool? billing, bool provideCubit = true}) async {
      final tenant = billing == null ? null : await _tenant(billing: billing);
      final passes = PassesCubit(MockPassesRepository());
      final open = OpenOrderCubit(MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero));
      final overview = HomeOverviewCubit(subs, invoices, kyc);
      addTearDown(() {
        tenant?.close();
        passes.close();
        open.close();
        overview.close();
      });
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => MultiBlocProvider(
              providers: [
                BlocProvider.value(value: passes),
                BlocProvider.value(value: open),
                if (provideCubit) BlocProvider.value(value: overview),
              ],
              child: DashboardPage(
                onTopUp: () {},
                onBuyPass: () {},
                onOpenPasses: () {},
                onReportIssue: () {},
                onResumeOrder: (_) {},
              ),
            ),
          ),
          GoRoute(
            path: '/invoices/:id',
            builder: (_, s) {
              pushed.add(s.uri.toString());
              return const Scaffold(body: Text('INVOICE SCREEN'));
            },
          ),
          GoRoute(
            path: '/kyc',
            builder: (_, s) {
              pushed.add(s.uri.toString());
              return const Scaffold(body: Text('KYC SCREEN'));
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view.physicalSize = const Size(390, 2400) * tester.view.devicePixelRatio;
      addTearDown(tester.view.resetPhysicalSize);
      final app = MaterialApp.router(
        routerConfig: router,
        theme: AppTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
      );
      await tester.pumpWidget(tenant == null ? app : BlocProvider.value(value: tenant, child: app));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('module off: pass-only Home, nothing requested', (tester) async {
      subs.services = [testService()];
      invoices.open = [_invoice()];
      await pump(tester, billing: false);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Your home internet'), findsNothing);
      expect(find.text('Home Hotspot 10'), findsNothing);
      expect(subs.calls + invoices.calls + kyc.calls, 0);
    });

    testWidgets('no tenant above: same as module off (and no cubit needed)', (tester) async {
      await pump(tester, provideCubit: false);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Your home internet'), findsNothing);
    });

    testWidgets('module on, no account: Home looks like today', (tester) async {
      kyc.failure = const SubscriberNotFoundFailure();
      await pump(tester, billing: true);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Your home internet'), findsNothing);
      expect(find.byKey(const Key('home-kyc-strip')), findsNothing);
    });

    testWidgets('hotspot subscriber with a pass: service card, paid until, open invoice, ID check', (tester) async {
      subs.services = [testService(paidThrough: DateTime.utc(2026, 12, 15))];
      invoices.open = [_invoice()];
      await pump(tester, billing: true);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.text('Your home internet'), findsOneWidget);
      expect(find.text('Home Hotspot 10'), findsOneWidget);
      expect(find.textContaining('Paid until'), findsOneWidget);
      expect(find.text('${formatRands(29900)} due Dec 1, 2026'), findsOneWidget);
      expect(find.text('Pay'), findsOneWidget);
      expect(find.text('We need to check your ID'), findsOneWidget);

      await tester.tap(find.byKey(const Key('home-invoice-inv-1')));
      await tester.pumpAndSettle();
      expect(pushed, ['/invoices/inv-1']);
    });

    testWidgets('fixed wireless: a card, no usage and no router status invented', (tester) async {
      subs.services = [testService(kind: SubscriberPlanKind.fixedWireless, planName: 'Air Fibre 20')];
      kyc.record = _kycRecord(KycStatus.verified);
      await pump(tester, billing: true);
      expect(find.text('Air Fibre 20'), findsOneWidget);
      expect(find.text('USED'), findsNothing);
      expect(find.textContaining('MAC'), findsNothing);
      expect(find.byIcon(Icons.router_outlined), findsNothing);
      // Verified ID: nothing to show.
      expect(find.byKey(const Key('home-kyc-strip')), findsNothing);
    });

    testWidgets('ID check strips follow the status and open the ID check', (tester) async {
      subs.services = [testService()];
      kyc.record = _kycRecord(KycStatus.rejected);
      await pump(tester, billing: true);
      expect(find.text('We could not accept your ID check'), findsOneWidget);
      await tester.tap(find.byKey(const Key('home-kyc-strip')));
      await tester.pumpAndSettle();
      expect(pushed, ['/kyc']);
    });

    testWidgets('part-paid invoice shows the amount left and no Pay label', (tester) async {
      subs.services = [testService()];
      invoices.open = [_invoice(paid: 10000)];
      kyc.record = _kycRecord(KycStatus.verified);
      await pump(tester, billing: true);
      expect(find.text('${formatRands(19900)} due Dec 1, 2026'), findsOneWidget);
      expect(find.text('Pay'), findsNothing);
    });

    testWidgets('services fail: invoices and the pass stay, services retry on their own', (tester) async {
      subs.failure = const ServerFailure();
      invoices.open = [_invoice()];
      kyc.record = _kycRecord(KycStatus.verified);
      await pump(tester, billing: true);
      expect(find.byKey(const Key('home-services-failure')), findsOneWidget);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.textContaining('due Dec 1, 2026'), findsOneWidget);

      subs.failure = null;
      subs.services = [testService()];
      final invoiceCallsBefore = invoices.calls;
      await tester.tap(
        find.descendant(of: find.byKey(const Key('home-services-failure')), matching: find.text('Retry')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Home Hotspot 10'), findsOneWidget);
      expect(find.byKey(const Key('home-services-failure')), findsNothing);
      expect(invoices.calls, invoiceCallsBefore);
    });

    testWidgets('invoices fail: cards stay with a small retry', (tester) async {
      subs.services = [testService()];
      invoices.failure = const ServerFailure();
      kyc.record = _kycRecord(KycStatus.verified);
      await pump(tester, billing: true);
      expect(find.text('Home Hotspot 10'), findsOneWidget);
      expect(find.byKey(const Key('home-invoices-failure')), findsOneWidget);
      invoices.failure = null;
      invoices.open = [_invoice()];
      await tester.tap(
        find.descendant(of: find.byKey(const Key('home-invoices-failure')), matching: find.text('Retry')),
      );
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('home-invoices-failure')), findsNothing);
      expect(find.textContaining('due Dec 1, 2026'), findsOneWidget);
    });

    testWidgets('offline: every failed section says so, the pass is unaffected', (tester) async {
      subs.failure = const NetworkFailure();
      invoices.failure = const NetworkFailure();
      kyc.failure = const NetworkFailure();
      await pump(tester, billing: true);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.byKey(const Key('home-services-failure')), findsOneWidget);
      expect(find.byKey(const Key('home-invoices-failure')), findsOneWidget);
      expect(find.byIcon(Icons.wifi_off), findsWidgets);
    });

    testWidgets('loading shows a spinner for services only', (tester) async {
      final gate = Completer<void>();
      subs = _SlowSubs(gate.future);
      await pump(tester, billing: true);
      expect(find.byKey(const Key('home-services-loading')), findsOneWidget);
      gate.complete();
      await tester.pump(const Duration(seconds: 1));
      expect(find.byKey(const Key('home-services-loading')), findsNothing);
    });

    testWidgets('pull to refresh reloads all three sources', (tester) async {
      subs.services = [testService()];
      await pump(tester, billing: true);
      expect([subs.calls, invoices.calls, kyc.calls], [1, 1, 1]);
      final indicator = tester.state<RefreshIndicatorState>(find.byType(RefreshIndicator));
      unawaited(indicator.show());
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(seconds: 1));
      expect([subs.calls, invoices.calls, kyc.calls], [2, 2, 2]);
    });
  });
}
