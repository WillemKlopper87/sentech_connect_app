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
import 'package:sentech_connect_app/features/credits/credits_gate.dart';
import 'package:sentech_connect_app/features/credits/presentation/pages/credits_home_page.dart';
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

/// `modules` and `credits` as the server would send them; null leaves the key out
/// (an older server that does not know it).
Future<TenantCubit> _tenant({Map<String, bool>? modules, bool? creditsFlag}) async {
  final base = fixtureMap('app_config.json');
  final flags = Map<String, Object?>.from(base['feature_flags']! as Map);
  if (creditsFlag != null) flags['credits'] = creditsFlag;
  final json = {...base, 'feature_flags': flags};
  if (modules != null) json['modules'] = modules;
  if (modules == null) json.remove('modules');
  final cubit = TenantCubit(
    repository: _TenantRepo(AppConfig.fromJson(json)),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  addTearDown(cubit.close);
  await cubit.bootstrap();
  return cubit;
}

/// Tears the app down inside the test, so its timers (the passes clock, demo latency) end before the checks.
Future<void> _disposeApp(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 2));
}

const _user = User(id: 'usr_001', fullName: 'Lindiwe', mobileNumber: '081');

void main() {
  setUpAppTests();

  group('creditsOn', () {
    test('needs the module AND the flag', () async {
      expect(creditsOn((await _tenant(modules: {'credits': true}, creditsFlag: true)).state), isTrue);
      expect(creditsOn((await _tenant(modules: {'credits': false}, creditsFlag: true)).state), isFalse);
      expect(creditsOn((await _tenant(modules: {'credits': true}, creditsFlag: false)).state), isFalse);
    });

    test('an_unknown_flag_reads_as_off: a server that sends no credits flag, or no modules, shows nothing', () async {
      expect(creditsOn((await _tenant(modules: {'credits': true})).state), isFalse, reason: 'flag missing');
      expect(creditsOn((await _tenant(creditsFlag: true)).state), isFalse, reason: 'modules not reported');
      expect(creditsOn(const TenantState()), isFalse, reason: 'no config yet');
      // The demo flag fallback (no config) must never open the gate, even with everything else on.
      expect(const TenantState().featureFlags.credits, isTrue, reason: 'the fallback flags are the demo flags');
      final ready = (await _tenant(modules: {'credits': true}, creditsFlag: true)).state;
      expect(creditsOn(ready), isTrue);
      expect(creditsOn(TenantState(config: ready.config, status: TenantStatus.loading)), isFalse, reason: 'not ready');
      expect(creditsOn(const TenantState(status: TenantStatus.ready)), isFalse, reason: 'ready but no config'); 
    });

    test('the flag decoder reads only a real true', () {
      expect(FeatureFlags.fromJson(const {'credits': 'yes'}).credits, isFalse);
      expect(FeatureFlags.fromJson(const {'credits': 1}).credits, isFalse);
      expect(FeatureFlags.fromJson(const {}).credits, isFalse);
      expect(FeatureFlags.fromJson(const {'credits': true}).credits, isTrue);
      expect(FeatureFlags.fromJson(FeatureFlags.demo.toJson()).credits, isTrue, reason: 'the cached config keeps it');
    });
  });

  group('the Rewards entries and routes', () {
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
      'the module is off': () => _tenant(modules: {'credits': false}, creditsFlag: true),
      'the flag is off': () => _tenant(modules: {'credits': true}, creditsFlag: false),
      'the flag is missing (older server)': () => _tenant(modules: {'credits': true}),
    };

    for (final MapEntry(key: reason, value: build) in off.entries) {
      testWidgets('credits_entry_is_hidden_when $reason', (tester) async {
        final tenant = await build();
        await pumpRouter(tester, tenant, AppRoutes.passes);
        expect(find.byKey(const Key('rewards-entry-card')), findsNothing);
        expect(find.byType(CreditsHomePage), findsNothing);
        // A deep link to Rewards goes home instead of showing an empty page.
        appRouter.router.go(AppRoutes.credits);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, AppRoutes.main);
        appRouter.router.go(AppRoutes.creditsRedeem);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, AppRoutes.main);
        await _disposeApp(tester);
      });
    }

    testWidgets('with the module and the flag on, My passes shows the card and it opens Rewards', (tester) async {
      final tenant = await _tenant(modules: {'credits': true}, creditsFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.passes);
      expect(find.byKey(const Key('rewards-entry-card')), findsOneWidget);
      await tester.tap(find.byKey(const Key('rewards-entry-card')));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.credits);
      expect(find.byType(CreditsHomePage), findsOneWidget);
      expect(find.byKey(const Key('credits-available')), findsOneWidget);
      await _disposeApp(tester);
    });

    testWidgets('Account has the Rewards row only when credits are on', (tester) async {
      final on = await _tenant(modules: {'credits': true}, creditsFlag: true);
      await pumpRouter(tester, on, AppRoutes.main);
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-rewards-row')), findsOneWidget);
      await _disposeApp(tester);
    });

    testWidgets('Account has no Rewards row when the flag is off', (tester) async {
      final tenant = await _tenant(modules: {'credits': true}, creditsFlag: false);
      await pumpRouter(tester, tenant, AppRoutes.main);
      await tester.tap(find.text('Account'));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('account-rewards-row')), findsNothing);
      await _disposeApp(tester);
    });

    testWidgets('View my passes after a redeem returns to the one passes page instead of stacking another', (tester) async {
      final tenant = await _tenant(modules: {'credits': true}, creditsFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.passes);
      await tester.tap(find.byKey(const Key('rewards-entry-card')));
      await tester.pumpAndSettle();
      appRouter.router.push(AppRoutes.creditsRedeem);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('credits-pack-50')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('credits-redeem-button')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('credits-view-passes')));
      await tester.pumpAndSettle();
      expect(appRouter.router.state.uri.path, AppRoutes.passes);
      final stack = appRouter.router.routerDelegate.currentConfiguration.matches.map((m) => m.matchedLocation).toList();
      expect(stack.where((p) => p == AppRoutes.passes), hasLength(1), reason: '$stack');
      expect(stack.where((p) => p.startsWith('/rewards')), isEmpty, reason: '$stack');
      await tester.pump(const Duration(seconds: 3)); // let the Home tabs under it finish their demo loads
      await _disposeApp(tester);
    });

    testWidgets('every Rewards sub-page opens when credits are on', (tester) async {
      final tenant = await _tenant(modules: {'credits': true}, creditsFlag: true);
      await pumpRouter(tester, tenant, AppRoutes.credits);
      for (final route in [
        AppRoutes.creditsRedeem,
        AppRoutes.creditsCheckIn,
        AppRoutes.creditsMissions,
        AppRoutes.creditsBadges,
        AppRoutes.creditsHistory,
      ]) {
        appRouter.router.go(route);
        await tester.pumpAndSettle();
        expect(appRouter.router.state.uri.path, route);
        expect(tester.takeException(), isNull, reason: route);
      }
      await _disposeApp(tester);
    });
  });
}
