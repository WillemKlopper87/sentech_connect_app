import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoice_detail_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoice_payment_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoices_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/invoice_detail_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/invoices_page.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'helpers/test_setup.dart';

class _TenantRepo implements TenantRepository {
  _TenantRepo(this.config);

  final AppConfig config;

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
}

Future<TenantCubit> _tenant(WidgetTester tester, {required bool moduleOn}) async {
  final config = AppConfig.fromJson({
    ...fixtureMap('app_config.json'),
    'modules': {'subscriber_billing': moduleOn},
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

/// Lists and details come from settable results.
class _Invoices implements InvoiceRepository {
  Either<Failure, List<SubscriberInvoice>> listResult = const Right([]);
  Either<Failure, SubscriberInvoice>? getResult;
  Either<Failure, PaymentHandoff>? checkoutResult;
  int listCalls = 0;

  @override
  Future<Either<Failure, List<SubscriberInvoice>>> list({bool openOnly = false}) async {
    listCalls++;
    return listResult;
  }

  @override
  Future<Either<Failure, SubscriberInvoice>> get(String id) async => getResult ?? const Left(NotFoundFailure());

  @override
  Future<Either<Failure, PaymentHandoff>> startCheckout(String id, {required String idempotencyKey}) async =>
      checkoutResult ?? const Left(NetworkFailure());
}

SubscriberInvoice _inv({
  String id = 'inv1',
  String no = 'INV-1',
  InvoiceStatus status = InvoiceStatus.open,
  int amount = 19900,
  int paid = 0,
  String kind = 'recurring',
}) => SubscriberInvoice(
  id: id,
  serviceId: 'svc1',
  invoiceNo: no,
  kind: kind,
  status: status,
  periodStart: DateTime.utc(2026, 12),
  periodEnd: DateTime.utc(2026, 12, 31),
  issueDate: DateTime.utc(2026, 11, 25),
  dueDate: DateTime.utc(2026, 12, 1),
  amountCents: amount,
  vatCents: 2596,
  amountPaidCents: paid,
  paidAt: status == InvoiceStatus.paid ? DateTime.utc(2026, 11, 26, 8) : null,
  lines: const [
    InvoiceLine(
      position: 1,
      kind: 'plan',
      description: 'Home Hotspot 10, December 2026',
      quantity: 1,
      unitPriceCents: 19900,
      lineTotalCents: 19900,
      vatRateBp: 1500,
      vatCents: 2596,
    ),
  ],
);

Widget _app(Widget home, {List<BlocProvider<StateStreamableSource<Object?>>> providers = const []}) {
  final app = MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
  return providers.isEmpty ? app : MultiBlocProvider(providers: providers, child: app);
}

const _user = User(id: 'usr_001', fullName: 'Lindiwe', mobileNumber: '081');

void main() {
  setUpAppTests();

  group('InvoicesPage', () {
    late _Invoices repo;

    Future<InvoicesCubit> pump(WidgetTester tester, {List<SubscriberInvoice>? opened}) async {
      final cubit = InvoicesCubit(repo);
      addTearDown(cubit.close);
      await tester.pumpWidget(
        _app(
          BlocProvider<InvoicesCubit>.value(value: cubit, child: InvoicesPage(onOpenInvoice: (i) => opened?.add(i))),
        ),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    setUp(() => repo = _Invoices());

    testWidgets('empty: says there are no invoices yet', (tester) async {
      await pump(tester);
      expect(find.text('No invoices yet'), findsOneWidget);
    });

    testWidgets('lists unpaid invoices first, then earlier ones, each in API order', (tester) async {
      repo.listResult = Right([
        _inv(id: 'a', no: 'INV-A', status: InvoiceStatus.paid, kind: 'initial'),
        _inv(id: 'b', no: 'INV-B'),
        _inv(id: 'c', no: 'INV-C', status: InvoiceStatus.voided),
      ]);
      final opened = <SubscriberInvoice>[];
      await pump(tester, opened: opened);
      double y(String text) => tester.getTopLeft(find.text(text)).dy;
      expect(find.text('To pay'), findsOneWidget);
      expect(find.text('Earlier invoices'), findsOneWidget);
      expect(y('INV-B'), lessThan(y('INV-A')));
      expect(y('INV-A'), lessThan(y('INV-C')));
      expect(find.text('First invoice'), findsOneWidget);
      expect(find.text('R199.00'), findsNWidgets(3));
      expect(find.text('Cancelled'), findsOneWidget);
      await tester.tap(find.text('INV-B'));
      expect(opened.single.id, 'b');
    });

    testWidgets('offline: offline wording and Retry loads again', (tester) async {
      repo.listResult = const Left(NetworkFailure());
      await pump(tester);
      expect(find.textContaining('offline'), findsOneWidget);
      repo.listResult = Right([_inv()]);
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('INV-1'), findsOneWidget);
    });

    testWidgets('a server error shows the failure and Retry', (tester) async {
      repo.listResult = const Left(ServerFailure('Something went wrong on our end.'));
      await pump(tester);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('INV-1'), findsNothing);
    });

    testWidgets('a failed refresh keeps the list and says why', (tester) async {
      repo.listResult = Right([_inv()]);
      final cubit = await pump(tester);
      repo.listResult = const Left(NetworkFailure());
      await cubit.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('INV-1'), findsOneWidget);
      expect(find.byType(SnackBar), findsOneWidget);
    });
  });

  group('InvoiceDetailPage', () {
    late _Invoices repo;

    Future<void> pump(WidgetTester tester, {InvoiceRepository? payments, SubscriberRepository? subscriber}) async {
      final detail = InvoiceDetailCubit(repo, 'inv1');
      final pay = InvoicePaymentCubit(
        payments ?? repo,
        subscriber ?? locator<SubscriberRepository>(),
        'inv1',
        pollDelays: const [Duration.zero],
        wait: (_) async {},
      );
      addTearDown(detail.close);
      addTearDown(pay.close);
      await tester.pumpWidget(
        _app(
          const InvoiceDetailPage(),
          providers: [BlocProvider<InvoiceDetailCubit>.value(value: detail), BlocProvider<InvoicePaymentCubit>.value(value: pay)],
        ),
      );
      await tester.pumpAndSettle();
    }

    setUp(() => repo = _Invoices());

    testWidgets('an open invoice shows lines, VAT, due date and a Pay button with the amount', (tester) async {
      repo.getResult = Right(_inv());
      await pump(tester);
      expect(find.text('Home Hotspot 10, December 2026'), findsOneWidget);
      expect(find.text('Includes VAT of R25.96'), findsOneWidget);
      expect(find.textContaining('Due '), findsOneWidget);
      expect(find.text('Pay R199.00'), findsOneWidget);
    });

    testWidgets('dates are shown as stored, never shifted a day', (tester) async {
      repo.getResult = Right(_inv());
      await pump(tester);
      expect(find.text('Period: Dec 1, 2026 to Dec 31, 2026'), findsOneWidget);
      expect(find.text('Issued Nov 25, 2026'), findsOneWidget);
      expect(find.text('Due Dec 1, 2026'), findsOneWidget);
    });

    testWidgets('a paid invoice shows when it was paid and has no Pay button', (tester) async {
      repo.getResult = Right(_inv(status: InvoiceStatus.paid, paid: 19900));
      await pump(tester);
      expect(find.textContaining('Paid '), findsWidgets);
      expect(find.textContaining('Pay R'), findsNothing);
    });

    testWidgets('void and written-off invoices say nothing is due and have no Pay button', (tester) async {
      repo.getResult = Right(_inv(status: InvoiceStatus.voided));
      await pump(tester);
      expect(find.text('This invoice was cancelled. Nothing is due.'), findsOneWidget);
      expect(find.textContaining('Pay R'), findsNothing);
      repo.getResult = Right(_inv(status: InvoiceStatus.writtenOff));
      await pump(tester);
      expect(find.text('This invoice was written off. Nothing is due.'), findsOneWidget);
    });

    testWidgets('a part-paid open invoice offers no Pay, only contact support', (tester) async {
      repo.getResult = Right(_inv(paid: 5000));
      await pump(tester);
      expect(find.textContaining('Part of this invoice is already paid'), findsOneWidget);
      expect(find.textContaining('Pay R'), findsNothing);
      expect(find.text('Paid so far'), findsOneWidget);
    });

    testWidgets('a zero-amount open invoice has no Pay button', (tester) async {
      repo.getResult = Right(_inv(amount: 0));
      await pump(tester);
      expect(find.textContaining('Pay R'), findsNothing);
    });

    testWidgets('not found and offline show the failure with Retry', (tester) async {
      await pump(tester);
      expect(find.text('Retry'), findsOneWidget);
      repo.getResult = const Left(NetworkFailure());
      await pump(tester);
      expect(find.textContaining('offline'), findsOneWidget);
    });

    testWidgets('demo: paying marks the invoice paid and says what is next', (tester) async {
      final demo = MockInvoiceRepository(latency: Duration.zero);
      final open = _firstOpen(demo, tester);
      final detail = InvoiceDetailCubit(demo, await open);
      final pay = InvoicePaymentCubit(
        demo,
        locator<SubscriberRepository>(),
        await open,
        pollDelays: const [Duration.zero],
        wait: (_) async {},
      );
      addTearDown(detail.close);
      addTearDown(pay.close);
      await tester.pumpWidget(
        _app(
          const InvoiceDetailPage(),
          providers: [BlocProvider<InvoiceDetailCubit>.value(value: detail), BlocProvider<InvoicePaymentCubit>.value(value: pay)],
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('pay-invoice')));
      await tester.pumpAndSettle(const Duration(milliseconds: 300));
      expect(find.text('Payment received'), findsOneWidget);
      expect(find.text('Thank you. This invoice is paid.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-invoice')), findsNothing);
    });

    testWidgets('a provider that collects its own money gets a message, not a retry', (tester) async {
      repo.getResult = Right(_inv());
      repo.checkoutResult = const Left(CollectionExternalFailure());
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('pay-invoice')));
      await tester.pumpAndSettle();
      expect(find.text('Your provider collects payment for this invoice directly.'), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-invoice')), findsNothing);
    });

    testWidgets('a failed start shows the failure and Pay can be tried again', (tester) async {
      repo.getResult = Right(_inv());
      repo.checkoutResult = const Left(NetworkFailure());
      await pump(tester);
      await tester.tap(find.byKey(const ValueKey('pay-invoice')));
      await tester.pumpAndSettle();
      expect(find.textContaining('offline'), findsOneWidget);
      expect(find.byKey(const ValueKey('pay-invoice')), findsOneWidget);
    });
  });

  group('routes', () {
    late AuthCubit auth;
    late AppRouter appRouter;

    Future<void> pumpRouter(WidgetTester tester, TenantCubit tenant, String at) async {
      auth = AuthCubit(
        locator(),
        sessionStore: locator(),
        biometrics: MockBiometricAuthenticator(),
        wiper: locator(),
        initial: const AuthState(status: AuthStatus.success, user: _user),
      );
      appRouter = AppRouter(auth, initialLocation: at, tenantCubit: tenant);
      addTearDown(() async {
        appRouter.dispose();
        await auth.close();
      });
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider.value(value: tenant),
            BlocProvider(create: (_) => CartCubit()),
            BlocProvider(create: (_) => ThemeCubit()),
            BlocProvider(create: (_) => LocaleCubit()),
          ],
          child: MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: appRouter.router,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('/invoices and /invoices/:id go home when the module is off', (tester) async {
      final tenant = await _tenant(tester, moduleOn: false);
      await pumpRouter(tester, tenant, AppRoutes.invoices);
      expect(appRouter.router.state.uri.path, AppRoutes.main);
      appRouter.router.go(AppRoutes.invoiceFor('x'));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.main);
    });

    testWidgets('/invoices opens the list when the module is on, and a row opens its detail', (tester) async {
      final tenant = await _tenant(tester, moduleOn: true);
      await pumpRouter(tester, tenant, AppRoutes.invoices);
      expect(appRouter.router.state.uri.path, AppRoutes.invoices);
      expect(find.text('INV-000102'), findsOneWidget);
      await tester.tap(find.text('INV-000102'));
      await tester.pumpAndSettle();
      expect(find.text('Pay R199.00'), findsOneWidget);
    });
  });
}

Future<String> _firstOpen(MockInvoiceRepository repo, WidgetTester tester) async {
  final list = (await tester.runAsync(() => repo.list(openOnly: true)))!;
  return list.getOrElse((f) => throw StateError(f.message)).first.id;
}
