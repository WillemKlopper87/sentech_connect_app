import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/main_shell.dart';
import 'package:sentech_connect_app/app/mock_feature_guard.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/promotions/domain/repositories/promotions_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  final prod = AppEnvironment.resolve(
    flavor: 'prod',
    apiBaseUrl: 'https://api.example.test',
    isDebug: false,
  );
  const demo = AppEnvironment.demo;

  group('the guard reads stillMockInProd', () {
    test('both engagement repositories are still mocks today', () {
      expect(stillMockInProd, containsAll([FreeWifiRepository, PromotionsRepository]));
    });

    test('prod hides both while they are mocks', () {
      expect(freeWifiVisible(prod, creditsModuleOn: true), isFalse);
      expect(promotionsVisible(prod), isFalse);
    });

    test('demo, dev and test builds always show them', () {
      expect(freeWifiVisible(demo, creditsModuleOn: false), isTrue);
      expect(promotionsVisible(demo), isTrue);
    });

    test('they come back in prod once the repository is real (off the list)', () {
      const realNow = <Type>[];
      expect(promotionsVisible(prod, mockInProd: realNow), isTrue);
      expect(freeWifiVisible(prod, creditsModuleOn: true, mockInProd: realNow), isTrue);
    });

    test('free Wi-Fi also needs the credits module once it is real', () {
      expect(freeWifiVisible(prod, creditsModuleOn: false, mockInProd: const []), isFalse);
    });

    test('promotions has no module and follows the guard alone', () {
      expect(promotionsVisible(prod, mockInProd: const [FreeWifiRepository]), isTrue);
      expect(promotionsVisible(prod, mockInProd: const [PromotionsRepository]), isFalse);
    });
  });

  group('entry points', () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<void> pump(
      WidgetTester tester, {
      required bool promotions,
      required bool freeWifi,
    }) async {
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
              showMockFeatures: false,
              showPromotions: promotions,
              showFreeWifi: freeWifi,
            ),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
    }

    Future<void> openVouchers(WidgetTester tester) async {
      await tester.tap(find.text('Shop'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.productCategoryVoucher));
      await tester.pumpAndSettle();
    }

    testWidgets('guard on: no promotions banner, no free Wi-Fi card; plain hotspot entry stays', (tester) async {
      await pump(tester, promotions: false, freeWifi: false);
      expect(find.text(l10n.homePromotionsLabel), findsNothing);
      await openVouchers(tester);
      expect(find.text(l10n.freeWifiFreeWifi), findsNothing);
      expect(find.text(l10n.freeWifiWatchAd), findsNothing);
      expect(find.byKey(const ValueKey('find-hotspots')), findsOneWidget);
    });

    testWidgets('guard off: promotions banner and the free Wi-Fi card show', (tester) async {
      await pump(tester, promotions: true, freeWifi: true);
      expect(find.text(l10n.homePromotionsLabel), findsOneWidget);
      await openVouchers(tester);
      expect(find.text(l10n.freeWifiFreeWifi), findsOneWidget);
      expect(find.byKey(const ValueKey('find-hotspots')), findsNothing);
    });
  });
}
