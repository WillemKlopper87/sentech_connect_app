import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/app/theme/app_theme.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart' show subscriberSignupFromJson;
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/plans_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/signup_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/pages/services_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/services_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/plan_detail_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/plans_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/signup_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/home_internet_section.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/widgets/monthly_plans_card.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'helpers/pump_themed.dart';
import 'helpers/test_setup.dart';
import 'signup_cubit_test.dart' show FakePlans, SignupRepo, hotspot, wireless;
import 'subscriber_services_cubit_test.dart' show FakeSubscriberRepository;

class _TenantRepo implements TenantRepository {
  _TenantRepo(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> _tenant(WidgetTester tester, {required bool on}) async {
  final config = AppConfig.fromJson({
    ...fixtureMap('app_config.json'),
    'modules': {'subscriber_billing': on},
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

const _user = User(id: 'usr_001', fullName: 'Lindiwe', mobileNumber: '081');

SubscriberPlan _full() => const SubscriberPlan(
  id: 'p-full',
  code: 'F',
  name: 'Fair Use Plan',
  description: 'Everything included.',
  kind: SubscriberPlanKind.recurringHotspot,
  kycRequired: false,
  priceCents: 29900,
  setupFeeCents: 5000,
  downKbps: 20000,
  upKbps: 7500,
  maxDevices: 1,
  fupAction: 'throttle',
  burstDownKbps: 40000,
  burstUpKbps: 10000,
  burstSeconds: 30,
  fupBytes: 214748364800,
  fupDownKbps: 2000,
  fupUpKbps: 1000,
);

void main() {
  setUpAppTests();
  setUpAll(() => initializeDateFormatting('en'));

  group('PlansPage', () {
    Future<void> pumpPlans(WidgetTester tester, FakePlans repo, {void Function(SubscriberPlan)? onOpen}) async {
      final cubit = PlansCubit(repo);
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(value: cubit, child: PlansPage(onOpenPlan: onOpen ?? (_) {})),
        size: const Size(390, 1600),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('cards show kind and ID-check chips, price, speeds and setup fee, cheapest first', (tester) async {
      await pumpPlans(tester, FakePlans([wireless(price: 80000), hotspot, wireless(id: 'cheap', price: 59900)]));
      expect(find.text('Monthly plans'), findsOneWidget);
      expect(find.text('Home hotspot'), findsOneWidget);
      expect(find.text('Fixed wireless'), findsNWidgets(2));
      expect(find.text('ID check needed'), findsNWidgets(2));
      expect(find.text('R199.00 a month'), findsOneWidget);
      expect(find.text('Down 10 Mbps, up 5 Mbps'), findsOneWidget);
      expect(find.text('Setup fee R999.00'), findsNWidgets(2));
      final tops = [for (final t in ['R199.00 a month', 'R599.00 a month', 'R800.00 a month']) tester.getTopLeft(find.text(t)).dy];
      expect([...tops]..sort(), tops, reason: 'hotspot, then wireless by price');
    });

    testWidgets('a tap opens the plan', (tester) async {
      SubscriberPlan? opened;
      await pumpPlans(tester, FakePlans([hotspot]), onOpen: (p) => opened = p);
      await tester.tap(find.text('Hotspot'));
      expect(opened?.id, 'p-hot');
    });

    testWidgets('empty list says so', (tester) async {
      await pumpPlans(tester, FakePlans(const []));
      expect(find.text('No plans available right now'), findsOneWidget);
    });

    testWidgets('failure shows retry; offline uses the offline wording', (tester) async {
      final repo = FakePlans(const [], failure: const NetworkFailure());
      await pumpPlans(tester, repo);
      expect(find.byIcon(Icons.wifi_off), findsOneWidget);
      repo
        ..failure = null
        ..plans = [hotspot];
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      expect(find.text('Hotspot'), findsOneWidget);
    });

    testWidgets('loading shows a spinner', (tester) async {
      final gate = Completer<void>();
      final cubit = PlansCubit(_GatedPlans(gate));
      addTearDown(cubit.close);
      await pumpThemed(tester, BlocProvider.value(value: cubit, child: PlansPage(onOpenPlan: (_) {})));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      gate.complete();
      await tester.pumpAndSettle();
    });
  });

  group('PlanDetailPage', () {
    Future<void> pumpDetail(WidgetTester tester, String id, FakePlans repo, {void Function(SubscriberPlan)? onChoose}) async {
      final cubit = PlansCubit(repo);
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: PlanDetailPage(planId: id, onChoose: onChoose ?? (_) {}, onBackToPlans: () {}),
        ),
        size: const Size(390, 1600),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('shows every fact: speeds, burst, fair use, devices, setup fee', (tester) async {
      await pumpDetail(tester, 'p-full', FakePlans([_full()]));
      expect(find.text('Fair Use Plan'), findsOneWidget);
      expect(find.text('R299.00 a month'), findsOneWidget);
      expect(find.text('Everything included.'), findsOneWidget);
      expect(find.text('Down 20 Mbps, up 7.5 Mbps'), findsOneWidget);
      expect(find.text('Bursts up to 40 / 10 Mbps for 30 seconds'), findsOneWidget);
      expect(find.text('Fair use: 200 GB a month'), findsOneWidget);
      expect(find.text('After that, speeds drop to 2 / 1 Mbps'), findsOneWidget);
      expect(find.text('1 device'), findsOneWidget);
      expect(find.text('Setup fee R50.00'), findsOneWidget);
    });

    testWidgets('Choose this plan hands the plan on', (tester) async {
      SubscriberPlan? chosen;
      await pumpDetail(tester, 'p-full', FakePlans([_full()]), onChoose: (p) => chosen = p);
      await tester.tap(find.byKey(const Key('plan-choose')));
      expect(chosen?.id, 'p-full');
    });

    testWidgets('a plan missing from the list says it is no longer available', (tester) async {
      await pumpDetail(tester, 'gone', FakePlans([hotspot]));
      expect(find.byKey(const Key('plan-missing')), findsOneWidget);
      expect(find.text('Back to plans'), findsOneWidget);
    });
  });

  group('SignupPage', () {
    late SignupRepo repo;
    String? payNow;
    String? payLater;
    var idChecks = 0;

    setUp(() {
      repo = SignupRepo();
      payNow = null;
      payLater = null;
      idChecks = 0;
    });

    Future<SignupCubit> pumpSignup(WidgetTester tester, String planId, {String? terms = '2026-09-30', bool idCheck = true}) async {
      final cubit = SignupCubit(
        FakePlans([hotspot, wireless()]),
        repo,
        planId,
        termsVersion: () => terms,
      );
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: SignupPage(
            onPayNow: (i) => payNow = i.id,
            onPayLater: (s) => payLater = s.id,
            onStartIdCheck: idCheck ? () => idChecks++ : null,
            onBackToPlans: () {},
          ),
        ),
        size: const Size(390, 1800),
      );
      await tester.pumpAndSettle();
      return cubit;
    }

    testWidgets('recurring plan: no address field; terms are required', (tester) async {
      await pumpSignup(tester, 'p-hot');
      expect(find.byKey(const Key('signup-address')), findsNothing);
      expect(find.text('Your first invoice covers the rest of this month, plus any setup fee. You see the exact amount before you pay.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Accept the terms to continue.'), findsOneWidget);
      expect(repo.calls, isEmpty);
    });

    testWidgets('fixed wireless: address field, availability note, ID check note; both are required', (tester) async {
      await pumpSignup(tester, 'p-air');
      expect(find.byKey(const Key('signup-address')), findsOneWidget);
      expect(find.text('Your provider confirms availability at your address.'), findsOneWidget);
      expect(find.text('This plan needs an ID check before it can start.'), findsOneWidget);
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.text('Enter the installation address.'), findsOneWidget);
      expect(repo.calls, isEmpty);
      await tester.enterText(find.byKey(const Key('signup-address')), '1 Main Road, Sandton');
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(repo.calls.single.address, '1 Main Road, Sandton');
    });

    testWidgets('success: first invoice, Pay now, Pay later, installation note and ID check button', (tester) async {
      await pumpSignup(tester, 'p-air');
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.enterText(find.byKey(const Key('signup-address')), '1 Main Road');
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-done')), findsOneWidget);
      final signup = subscriberSignupFromJson(fixtureMap('subscriber_signup.json'));
      expect(find.text('First invoice INV-000101: R1099.00, due Nov 1, 2026'), findsOneWidget);
      // The platform's blocker, in its own words.
      expect(find.text('Pay your first invoice to start'), findsOneWidget);
      expect(find.byKey(const Key('signup-installation')), findsOneWidget);
      await tester.tap(find.byKey(const Key('signup-pay-now')));
      expect(payNow, signup.invoice.id);
      await tester.tap(find.byKey(const Key('signup-pay-later')));
      expect(payLater, signup.service.id);
      await tester.tap(find.byKey(const Key('signup-id-check')));
      expect(idChecks, 1);
    });

    testWidgets('on a short screen the form scrolls and can be completed', (tester) async {
      final cubit = SignupCubit(FakePlans([wireless()]), repo, 'p-air', termsVersion: () => '2026-09-30');
      addTearDown(cubit.close);
      await pumpThemed(
        tester,
        BlocProvider.value(
          value: cubit,
          child: SignupPage(onPayNow: (_) {}, onPayLater: (_) {}, onStartIdCheck: null, onBackToPlans: () {}),
        ),
        size: const Size(360, 520),
      );
      await tester.pumpAndSettle();
      await tester.enterText(find.byKey(const Key('signup-address')), '1 Main Road');
      await tester.scrollUntilVisible(find.byKey(const Key('signup-terms')), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.scrollUntilVisible(find.byKey(const Key('signup-submit')), 100, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-done')), findsOneWidget);
    });

    testWidgets('success on a hotspot plan: no installation note and no ID check button', (tester) async {
      repo.replies.add(
        Right(subscriberSignupFromJson({
          ...fixtureMap('subscriber_signup.json'),
          'service': {...(fixtureMap('subscriber_signup.json')['service']! as Map<String, Object?>), 'kind': 'recurring_hotspot'},
        })),
      );
      await pumpSignup(tester, 'p-hot');
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-done')), findsOneWidget);
      expect(find.byKey(const Key('signup-installation')), findsNothing);
      expect(find.byKey(const Key('signup-id-check')), findsNothing);
    });

    testWidgets('each refusal shows its own customer sentence and keeps the form', (tester) async {
      const cases = <(Failure, String)>[
        (SubscriberProfileInvalidFailure(), 'Update your contact details before signing up.'),
        (CustomerLinkRequiredFailure(), 'Your account is not linked to your provider yet. Contact your provider.'),
        (ServiceStateFailure('account_closed'), 'Your account is closed. Contact your provider.'),
        (ConsentVersionOutdatedFailure(), 'The terms were updated. Please review and accept the latest version.'),
        (NetworkFailure(), "You're offline. Check your connection and try again."),
      ];
      for (final (failure, text) in cases) {
        repo.replies.add(Left(failure));
        await pumpSignup(tester, 'p-hot');
        await tester.tap(find.byKey(const Key('signup-terms')));
        await tester.tap(find.byKey(const Key('signup-submit')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('signup-failure')), findsOneWidget, reason: '$failure');
        expect(find.textContaining(text.split('.').first), findsOneWidget, reason: '$failure');
        expect(find.byKey(const Key('signup-submit')), findsOneWidget);
      }
    });

    testWidgets('a plan that is no longer available shows the plan sentence and a way back', (tester) async {
      repo.replies.add(const Left(PlanUnavailableFailure('subscriber_plan_inactive')));
      await pumpSignup(tester, 'p-hot');
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-plan-missing')), findsOneWidget);
      expect(find.text('Back to plans'), findsOneWidget);
    });

    testWidgets('while sending the button is disabled and says so', (tester) async {
      repo.gate = Completer<void>();
      await pumpSignup(tester, 'p-hot');
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pump();
      expect(find.text('Signing up…'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const Key('signup-submit'))).onPressed, isNull);
      repo.gate!.complete();
      await tester.pumpAndSettle();
    });
  });

  group('entry points', () {
    testWidgets('the Shop card shows with the module on and opens the plans route', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Scaffold(body: MonthlyPlansCard())),
          GoRoute(path: '/plans', builder: (_, _) => const Scaffold(body: Text('PLANS SCREEN'))),
        ],
      );
      addTearDown(router.dispose);
      Future<void> pump(TenantCubit? tenant) async {
        final app = MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        );
        await tester.pumpWidget(tenant == null ? app : BlocProvider.value(value: tenant, child: app));
        await tester.pumpAndSettle();
      }

      await pump(await _tenant(tester, on: true));
      expect(find.text('Monthly plans'), findsOneWidget);
      await tester.tap(find.byKey(const Key('shop-monthly-plans')));
      await tester.pumpAndSettle();
      expect(find.text('PLANS SCREEN'), findsOneWidget);
    });

    testWidgets('the Shop card is absent with the module off or no tenant', (tester) async {
      for (final tenant in [await _tenant(tester, on: false), null]) {
        final app = MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: MonthlyPlansCard()),
        );
        await tester.pumpWidget(tenant == null ? app : BlocProvider.value(value: tenant, child: app));
        await tester.pumpAndSettle();
        expect(find.text('Monthly plans'), findsNothing);
      }
    });

    testWidgets('the Account section lists Monthly plans (registered by S5)', (tester) async {
      expect(subscriberEntryRegistered(AppRoutes.plans), isTrue);
      final tenant = await _tenant(tester, on: true);
      await tester.pumpWidget(
        BlocProvider.value(
          value: tenant,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ListView(children: const [HomeInternetSection()])),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Monthly plans'), findsOneWidget);
    });

    testWidgets('the empty services state offers See plans', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider(
              create: (_) => ServicesCubit(FakeSubscriberRepository(services: const [])),
              child: const ServicesPage(),
            ),
          ),
          GoRoute(path: '/plans', builder: (_, _) => const Scaffold(body: Text('PLANS SCREEN'))),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          routerConfig: router,
          theme: AppTheme.light(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('You have no home internet service yet'), findsOneWidget);
      await tester.tap(find.byKey(const Key('services-see-plans')));
      await tester.pumpAndSettle();
      expect(find.text('PLANS SCREEN'), findsOneWidget);
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

    testWidgets('/plans, /plans/:id and /signup/:id go home when the module is off', (tester) async {
      final tenant = await _tenant(tester, on: false);
      await pumpRouter(tester, tenant, AppRoutes.plans);
      expect(appRouter.router.state.uri.path, AppRoutes.main);
      for (final path in [AppRoutes.planFor('x'), AppRoutes.signupFor('x')]) {
        appRouter.router.go(path);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, AppRoutes.main, reason: path);
      }
    });

    testWidgets('module on: plans -> detail -> sign-up -> first invoice -> Pay now opens the invoice', (tester) async {
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      final tenant = await _tenant(tester, on: true);
      await pumpRouter(tester, tenant, AppRoutes.plans);
      expect(appRouter.router.state.uri.path, AppRoutes.plans);
      await tester.tap(find.text('Home Air 50'));
      await tester.pumpAndSettle();
      expect(find.text('Plan details'), findsOneWidget);
      await tester.tap(find.byKey(const Key('plan-choose')));
      await tester.pumpAndSettle();
      expect(find.text('Confirm sign-up'), findsOneWidget);
      await tester.enterText(find.byKey(const Key('signup-address')), '1 Main Road');
      await tester.ensureVisible(find.byKey(const Key('signup-terms')));
      await tester.tap(find.byKey(const Key('signup-terms')));
      await tester.ensureVisible(find.byKey(const Key('signup-submit')));
      await tester.tap(find.byKey(const Key('signup-submit')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('signup-done')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('signup-pay-now')));
      await tester.tap(find.byKey(const Key('signup-pay-now')));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, startsWith('/invoices/'));
    });
  });
}

class _GatedPlans extends FakePlans {
  _GatedPlans(this.gate) : super(const []);
  final Completer<void> gate;
  @override
  Future<Either<Failure, List<SubscriberPlan>>> list() async {
    await gate.future;
    return super.list();
  }
}
