import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/main_shell.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';
import 'package:sentech_connect_app/features/voucher_scanner/presentation/pages/voucher_scanner_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/fixtures.dart';
import 'helpers/test_setup.dart';

class _FakeRepo implements TenantRepository {
  _FakeRepo(this.config);

  final AppConfig config;

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);
}

Future<TenantCubit> pumpShell(WidgetTester tester, {required Map<String, bool> modules}) async {
  final config = AppConfig.fromJson({...fixtureMap('app_config.json'), 'modules': modules});
  final cubit = TenantCubit(
    repository: _FakeRepo(config),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(slug: 'acme-wifi'),
  );
  addTearDown(cubit.close);
  await cubit.bootstrap();
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
        BlocProvider.value(value: cubit),
        BlocProvider.value(value: auth),
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
          showRouterCard: false,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
  return cubit;
}

void main() {
  setUpAppTests();

  testWidgets('vouchers module off: no Scan tab; on: Scan tab', (tester) async {
    await pumpShell(tester, modules: {'vouchers': false});
    expect(find.text('Scan'), findsNothing);
    await pumpShell(tester, modules: {'vouchers': true});
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('module goes off while Scan is selected: no range error', (tester) async {
    final cubit = await pumpShell(tester, modules: {'vouchers': true});
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    cubit.moduleRefused('vouchers');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(find.text('Account'), findsOneWidget);
  });

  testWidgets('the selected tab disappears: Home is shown, no exception', (tester) async {
    final cubit = await pumpShell(tester, modules: {'vouchers': true});
    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();
    cubit.moduleRefused('vouchers');
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    expect(tester.widget<IndexedStack>(find.byType(IndexedStack)).index, 0);
    expect(tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex, 0);
    expect(find.byType(VoucherScannerPage), findsNothing);
  });
}
