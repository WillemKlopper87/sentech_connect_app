import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/app/main_shell.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'helpers/test_setup.dart';

class _ConfigRepo implements TenantRepository {
  _ConfigRepo(this.config);
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

Future<void> _pump(WidgetTester tester, {required bool mock, TenantCubit? tenant}) async {
  final auth = AuthCubit(
    locator(),
    sessionStore: locator(),
    biometrics: MockBiometricAuthenticator(),
    wiper: locator(),
  );
  addTearDown(auth.close);
  await tester.pumpWidget(
    MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        if (tenant != null) BlocProvider.value(value: tenant),
        BlocProvider(create: (_) => CartCubit()),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: MainShell(
          onOpenCart: () {},
          onResumeOrder: (_) {},
          onOpenPromotions: () {},
          onFindHotspots: () {},
          showMockFeatures: mock,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAppTests();

  testWidgets(
    'demo: Scan and Support tabs and the report-issue shortcut show',
    (tester) async {
      await _pump(tester, mock: true);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget);
      expect(find.text('Report issue'), findsOneWidget);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en')).homePromotionsLabel,
        ),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'prod: Scan (real voucher redemption), contact support and report-issue show; the mock FAQ and promotions do not',
    (tester) async {
      await _pump(tester, mock: false);
      expect(
        find.descendant(
          of: find.byType(NavigationBar),
          matching: find.text('Home'),
        ),
        findsOneWidget,
      );
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Help'), findsOneWidget, reason: 'contact support is real');
      expect(find.text('Report issue'), findsOneWidget);
      expect(
        find.text(
          lookupAppLocalizations(const Locale('en')).homePromotionsLabel,
        ),
        findsNothing,
      );
    },
  );

  group('Home subscriber sections are wired from the locator', () {
    Future<TenantCubit> tenantWith({required bool billing}) async {
      final config = AppConfig.fromJson({
        ...fixtureMap('app_config.json'),
        'modules': {'subscriber_billing': billing},
      });
      final cubit = TenantCubit(
        repository: _ConfigRepo(config),
        context: TenantContext(),
        preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
      );
      addTearDown(cubit.close);
      await cubit.bootstrap();
      return cubit;
    }

    testWidgets('module on: the demo service and open invoice show on Home', (tester) async {
      await _pump(tester, mock: true, tenant: await tenantWith(billing: true));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Your home internet'), findsOneWidget);
      expect(find.text('Home Hotspot 10'), findsOneWidget);
    });

    testWidgets('module off: Home is the pass-only one', (tester) async {
      await _pump(tester, mock: true, tenant: await tenantWith(billing: false));
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Your home internet'), findsNothing);
      expect(find.text('Home Hotspot 10'), findsNothing);
    });
  });
}
