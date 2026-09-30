import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/theme/theme_cubit.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/account/presentation/pages/account_page.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';
import 'package:sentech_connect_app/features/rica/presentation/pages/rica_page.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
import 'helpers/test_setup.dart';

List<bool> secureCalls() => [
      for (final c in platformCalls)
        if (c.method == 'setSecure') (c.arguments as Map)['enabled'] as bool,
    ];

void main() {
  setUpAppTests();

  testWidgets('SecureScreen turns FLAG_SECURE on while mounted and off when removed', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SecureScreen(child: Text('secret'))));
    expect(ScreenSecurity.isProtected, isTrue);
    expect(secureCalls(), [true]);

    await tester.pumpWidget(const MaterialApp(home: Text('public')));
    expect(ScreenSecurity.isProtected, isFalse);
    expect(secureCalls(), [true, false]);
  });

  testWidgets('protection is reference counted: one screen closing does not expose another', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Column(children: [SecureScreen(child: Text('a')), SecureScreen(child: Text('b'))]),
    ));
    expect(secureCalls(), [true]); // a single platform call for two holders

    await tester.pumpWidget(const MaterialApp(home: Column(children: [SecureScreen(child: Text('a'))])));
    expect(ScreenSecurity.isProtected, isTrue);
    expect(secureCalls(), [true]);
  });

  testWidgets('a hidden tab (TickerMode off) is not protected; showing it is', (tester) async {
    Widget tab(bool visible) => MaterialApp(
          home: TickerMode(enabled: visible, child: const SecureScreen(child: Text('tab'))),
        );
    await tester.pumpWidget(tab(false));
    expect(ScreenSecurity.isProtected, isFalse);
    await tester.pumpWidget(tab(true));
    expect(ScreenSecurity.isProtected, isTrue);
    await tester.pumpWidget(tab(false));
    expect(ScreenSecurity.isProtected, isFalse);
  });

  testWidgets('the RICA screen is capture-protected', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider(
        create: (_) => RicaCubit(locator(), locator(), 'ord'),
        child: RicaPage(onVerified: () {}),
      ),
    ));
    expect(ScreenSecurity.isProtected, isTrue);
    await tester.pumpWidget(const MaterialApp(home: SizedBox()));
    expect(ScreenSecurity.isProtected, isFalse);
  });

  testWidgets('the Account screen is capture-protected', (tester) async {
    final auth = AuthCubit(
      locator(),
      sessionStore: locator(),
      biometrics: MockBiometricAuthenticator(),
      wiper: locator(),
    );
    addTearDown(auth.close);
    await tester.pumpWidget(MultiBlocProvider(
      providers: [
        BlocProvider.value(value: auth),
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => LocaleCubit()),
      ],
      child: const MaterialApp(home: AccountPage()),
    ));
    expect(ScreenSecurity.isProtected, isTrue);
  });
}
