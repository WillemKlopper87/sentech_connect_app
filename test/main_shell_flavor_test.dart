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
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/test_setup.dart';

Future<void> _pump(WidgetTester tester, {required bool mock}) async {
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
          showMockFeatures: mock,
          showRouterCard: false,
        ),
      ),
    ),
  );
  await tester.pump(const Duration(seconds: 1));
}

void main() {
  setUpAppTests();

  test('the router card needs the demo flavor AND the cpe flag', () {
    expect(showRouterCardFor(isDemo: true, cpe: true), isTrue);
    expect(showRouterCardFor(isDemo: true, cpe: false), isFalse);
    expect(showRouterCardFor(isDemo: false, cpe: true), isFalse);
    expect(showRouterCardFor(isDemo: false, cpe: false), isFalse);
  });

  testWidgets(
    'demo: Scan and Support tabs and the report-issue shortcut show',
    (tester) async {
      await _pump(tester, mock: true);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Support'), findsOneWidget);
      expect(find.text('Report issue'), findsOneWidget);
    },
  );

  testWidgets(
    'prod: Scan (real voucher redemption) shows; mock-backed Support and report-issue are hidden',
    (tester) async {
      await _pump(tester, mock: false);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Shop'), findsOneWidget);
      expect(find.text('Account'), findsOneWidget);
      expect(find.text('Scan'), findsOneWidget);
      expect(find.text('Support'), findsNothing);
      expect(find.text('Report issue'), findsNothing);
    },
  );
}
