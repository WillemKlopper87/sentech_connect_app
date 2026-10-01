import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/registration_page.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

import 'helpers/test_setup.dart';

const _newCustomer = User(id: 'new-1', fullName: '', mobileNumber: '+27821234567');

void main() {
  setUpAppTests();

  late AuthCubit auth;

  setUp(() {
    auth = AuthCubit(
      locator(),
      sessionStore: locator(),
      biometrics: MockBiometricAuthenticator(),
      wiper: locator(),
      initial: const AuthState(status: AuthStatus.success, user: _newCustomer, freshSignIn: true),
    );
  });

  tearDown(() => auth.close());

  Future<void> pumpPage(WidgetTester tester) async {
    // Tall enough to show the whole form without scrolling.
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(BlocProvider.value(value: auth, child: const MaterialApp(home: RegistrationPage())));
    await tester.pumpAndSettle();
  }

  Finder field(String hint) => find.widgetWithText(TextField, hint);

  testWidgets('the verified number is prefilled and cannot be edited', (tester) async {
    await pumpPage(tester);
    final mobile = tester.widget<TextField>(find.byWidgetPredicate((w) => w is TextField && w.controller?.text == '+27821234567'));
    expect(mobile.readOnly, isTrue);
  });

  testWidgets('the button stays disabled until the terms are accepted', (tester) async {
    await pumpPage(tester);
    await tester.enterText(field('Full name'), 'Thandi Mokoena');
    await tester.enterText(field('Email address'), 'thandi@example.test');
    await tester.enterText(field('Street address, suburb, city'), '12 Main Road, Soweto');
    await tester.pump();
    final button = find.widgetWithText(ElevatedButton, 'Create account');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNull);

    await tester.tap(find.text('I accept the Terms of Service and the Privacy notice'));
    await tester.pump();
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
  });

  testWidgets('saving completes the signed-in profile and records the consents', (tester) async {
    await pumpPage(tester);
    await tester.enterText(field('Full name'), ' Thandi Mokoena ');
    await tester.enterText(field('Email address'), 'thandi@example.test');
    await tester.enterText(field('Street address, suburb, city'), '12 Main Road, Soweto');
    await tester.tap(find.text('I accept the Terms of Service and the Privacy notice'));
    await tester.pump();
    final button = find.widgetWithText(ElevatedButton, 'Create account');
    expect(tester.widget<ElevatedButton>(button).onPressed, isNotNull);
    await tester.tap(button);
    await tester.pumpAndSettle();

    expect(auth.state.user!.id, 'new-1', reason: 'same customer, now with a name');
    expect(auth.state.user!.fullName, 'Thandi Mokoena');
    expect(auth.state.user!.mobileNumber, '+27821234567');
    expect(auth.state.freshSignIn, isTrue);
    final consents = locator<ConsentRepository>();
    for (final purpose in [ConsentPurpose.terms, ConsentPurpose.privacy]) {
      expect((await consents.currentConsent(purpose)).getOrElse((_) => null), isNotNull, reason: '$purpose');
    }
    expect((await consents.currentConsent(ConsentPurpose.marketingSms)).getOrElse((_) => null), isNull, reason: 'not opted in');
  });
}
