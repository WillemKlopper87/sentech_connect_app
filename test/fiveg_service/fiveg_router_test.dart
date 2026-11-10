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
import 'package:sentech_connect_app/features/fiveg_service/presentation/pages/fiveg_usage_page.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_entries.dart';
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

const _user = User(id: 'usr_001', fullName: 'Lindiwe', mobileNumber: '081');
const _service = 'a6b4c2d0-1111-4a22-8b33-00000000c001';

void main() {
  setUpAppTests();

  group('5G data route and the service row', () {
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

    testWidgets('/fiveg/:serviceId goes home when the subscriber module is off', (tester) async {
      final tenant = await _tenant(tester, moduleOn: false);
      await pumpRouter(tester, tenant, AppRoutes.fivegFor(_service));
      expect(appRouter.router.state.uri.path, AppRoutes.main);
    });

    testWidgets('/fiveg/:serviceId opens the usage screen when the module is on', (tester) async {
      final tenant = await _tenant(tester, moduleOn: true);
      await pumpRouter(tester, tenant, AppRoutes.fivegFor(_service));
      expect(appRouter.router.state.uri.path, AppRoutes.fivegFor(_service));
      expect(find.byType(FiveGUsagePage), findsOneWidget);
      expect(find.text('Full speed. You can use your data as normal.'), findsOneWidget);
    });

    test('the data-unlock payment and confirmation routes carry the service only when given', () {
      expect(AppRoutes.paymentFor('o1'), '/payment/o1');
      expect(AppRoutes.paymentFor('o1', service: _service), '/payment/o1?service=$_service');
      expect(AppRoutes.confirmationFor('o1'), '/confirmation/o1');
      expect(AppRoutes.confirmationFor('o1', service: _service), '/confirmation/o1?service=$_service');
      expect(AppRoutes.fivegFor(_service), '/fiveg/$_service');
    });

    test('the 5G row is not an account-level entry: it needs a service id, so it is not in the registry', () {
      expect(subscriberEntryRegistered(AppRoutes.fiveg), isFalse);
    });
  });
}
