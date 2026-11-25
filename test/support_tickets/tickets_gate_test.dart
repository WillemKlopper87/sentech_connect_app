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
import 'package:sentech_connect_app/features/support/presentation/pages/tickets_page.dart';
import 'package:sentech_connect_app/features/support/tickets_gate.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import '../helpers/fixtures.dart';
import '../helpers/test_setup.dart';

class _TenantRepo implements TenantRepository {
  _TenantRepo(this.config);

  final AppConfig config;

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
}

/// `modules` and `ticketing` as the server would send them; null leaves the key out
/// (an older server that does not know it). [ticketingFlag] may be any JSON value.
Future<TenantCubit> _tenant({Map<String, bool>? modules, Object? ticketingFlag}) async {
  final base = fixtureMap('app_config.json');
  final flags = Map<String, Object?>.from(base['feature_flags']! as Map);
  if (ticketingFlag != null) flags['ticketing'] = ticketingFlag;
  final json = {...base, 'feature_flags': flags};
  if (modules != null) {
    json['modules'] = modules;
  } else {
    json.remove('modules');
  }
  final cubit = TenantCubit(
    repository: _TenantRepo(AppConfig.fromJson(json)),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  addTearDown(cubit.close);
  await cubit.bootstrap();
  return cubit;
}

/// Tears the app down inside the test, so its timers end before the checks.
Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

const _user = User(id: 'usr_001', fullName: 'Lindiwe', mobileNumber: '081');

void main() {
  setUpAppTests();

  group('ticketsOn', () {
    test('needs the module AND the flag', () async {
      expect(ticketsOn((await _tenant(modules: {'tickets': true}, ticketingFlag: true)).state), isTrue);
      expect(ticketsOn((await _tenant(modules: {'tickets': false}, ticketingFlag: true)).state), isFalse);
      expect(ticketsOn((await _tenant(modules: {'tickets': true}, ticketingFlag: false)).state), isFalse);
    });

    test('an_unknown_flag_reads_as_off', () async {
      expect(ticketsOn((await _tenant(modules: {'tickets': true})).state), isFalse, reason: 'flag missing');
      expect(ticketsOn((await _tenant(modules: {'tickets': true}, ticketingFlag: 'true')).state), isFalse, reason: 'a string is not true');
      expect(ticketsOn((await _tenant(modules: {'tickets': true}, ticketingFlag: 1)).state), isFalse, reason: 'a number is not true');
      expect(ticketsOn((await _tenant(ticketingFlag: true)).state), isFalse, reason: 'modules not reported');
      expect(ticketsOn(const TenantState()), isFalse, reason: 'no config yet, even though the demo fallback flags are on');
      final ready = (await _tenant(modules: {'tickets': true}, ticketingFlag: true)).state;
      expect(ticketsOn(TenantState(config: ready.config, status: TenantStatus.loading)), isFalse, reason: 'not ready');
      expect(ticketsOn(const TenantState(status: TenantStatus.ready)), isFalse, reason: 'ready but no config');
    });

    test('the flag decoder reads only a real true, and the cached config keeps it', () {
      expect(FeatureFlags.fromJson(const {'ticketing': 'yes'}).ticketing, isFalse);
      expect(FeatureFlags.fromJson(const {}).ticketing, isFalse);
      expect(FeatureFlags.fromJson(const {'ticketing': true}).ticketing, isTrue);
      expect(FeatureFlags.fromJson(FeatureFlags.demo.toJson()).ticketing, isTrue);
    });

    test('the demo config has the tickets module on, so the demo shows the screens', () {
      expect(MockTenantRepository.demoConfig.isModuleOn(AppModuleKeys.tickets), isTrue);
      expect(MockTenantRepository.demoConfig.featureFlags.ticketing, isTrue);
    });

    test('a 409 feature_disabled hides the entry at once, through the same refuse-module hook as credits', () async {
      final tenant = await _tenant(modules: {'tickets': true}, ticketingFlag: true);
      expect(ticketsOn(tenant.state), isTrue);
      tenant.moduleRefused(AppModuleKeys.tickets);
      expect(ticketsOn(tenant.state), isFalse);
    });
  });

  group('the entries and routes', () {
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

    final off = <String, Future<TenantCubit> Function()>{
      'the module is off': () => _tenant(modules: {'tickets': false}, ticketingFlag: true),
      'the flag is off': () => _tenant(modules: {'tickets': true}, ticketingFlag: false),
      'the flag is missing (older server)': () => _tenant(modules: {'tickets': true}),
    };

    for (final MapEntry(key: reason, value: build) in off.entries) {
      testWidgets('entry_is_hidden_when $reason: no entries, the routes go home, the contact form still works', (tester) async {
        final tenant = await build();
        await pumpRouter(tester, tenant, AppRoutes.main);
        await tester.tap(find.text('Help'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('help-my-tickets')), findsNothing);
        expect(find.byKey(const Key('help-new-ticket')), findsNothing);
        expect(find.byKey(const Key('incident-notice-card')), findsNothing);
        // The existing one-way contact form is unchanged.
        expect(find.text('Submit a ticket'), findsOneWidget);
        await tester.tap(find.text('Submit a ticket'));
        await tester.pumpAndSettle();
        expect(find.text('Message support'), findsOneWidget);
        expect(find.text('Send message'), findsOneWidget);
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Account'));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('account-tickets-row')), findsNothing);
        appRouter.router.go(AppRoutes.tickets);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, AppRoutes.main);
        appRouter.router.go(AppRoutes.ticketsNew);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, AppRoutes.main);
        appRouter.router.go(AppRoutes.ticketFor('TKT-7K3M9Q2A'));
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, AppRoutes.main);
        await _disposeApp(tester);
      });
    }

    testWidgets('with the module and the flag on, Help and Account have the entries and they open the screens', (tester) async {
      final tenant = await _tenant(modules: {'tickets': true}, ticketingFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.main);
      await tester.tap(find.text('Help'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('help-my-tickets')), findsOneWidget);
      expect(find.byKey(const Key('help-new-ticket')), findsOneWidget);
      // The demo incident notice shows on Help, with the demo provider's words.
      expect(find.byKey(const Key('incident-notice-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('help-my-tickets')));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.tickets);
      expect(find.byType(TicketsPage), findsOneWidget);
      // A demo ticket opens by its reference, and the thread is the demo one.
      await tester.tap(find.byKey(const Key('tickets-new-button')));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.ticketsNew);
      await _disposeApp(tester);
    });

    testWidgets('Report an issue on the dashboard opens a new ticket when ticketing is on', (tester) async {
      final tenant = await _tenant(modules: {'tickets': true}, ticketingFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.main);
      await tester.tap(find.text('Report issue'));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.ticketsNew);
      await _disposeApp(tester);
    });

    testWidgets('Report an issue on the dashboard is the one-way form when ticketing is off', (tester) async {
      final tenant = await _tenant(modules: {'tickets': false}, ticketingFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.main);
      await tester.tap(find.text('Report issue'));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.main);
      expect(find.text('Send message'), findsOneWidget);
      await _disposeApp(tester);
    });

    testWidgets('Account has the My tickets row only when ticketing is on', (tester) async {
      final tenant = await _tenant(modules: {'tickets': true}, ticketingFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.main);
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-tickets-row')), findsOneWidget);
      await _disposeApp(tester);
    });

    testWidgets('switching ticketing off mid-session closes the screens and drops the draft with them', (tester) async {
      final tenant = await _tenant(modules: {'tickets': true}, ticketingFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.ticketsNew);
      expect(find.byKey(const Key('ticket-body-field')), findsOneWidget);
      await tester.enterText(find.byKey(const Key('ticket-body-field')), 'A draft');
      tenant.moduleRefused(AppModuleKeys.tickets);
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.main);
      expect(find.text('A draft'), findsNothing);
      await _disposeApp(tester);
    });

    testWidgets('every ticket route opens when ticketing is on, with no ticket text in the location', (tester) async {
      final tenant = await _tenant(modules: {'tickets': true}, ticketingFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.tickets);
      for (final route in [AppRoutes.ticketsNew, AppRoutes.ticketFor('TKT-7K3M9Q2A')]) {
        appRouter.router.go(route);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, route);
        expect(appRouter.router.state.extra, isNull, reason: 'nothing the customer typed travels in a route');
        expect(tester.takeException(), isNull, reason: route);
      }
      await _disposeApp(tester);
    });
  });
}
