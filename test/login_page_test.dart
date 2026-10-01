import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

import 'helpers/test_setup.dart';

/// A first-time customer: the platform creates the account on the first verified code, with no name yet.
class _NewCustomerRepository extends MockAuthRepository {
  _NewCustomerRepository() : super(latency: Duration.zero);

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async =>
      Right(User(id: 'new-1', fullName: '', mobileNumber: challenge.phoneE164));
}

void main() {
  setUpAppTests();

  late AuthCubit auth;

  setUp(() async {
    locator.registerSingleton<AuthRepository>(MockAuthRepository(latency: Duration.zero));
    auth = AuthCubit(locator(), sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
    // These tests are about the code flow; the terms step has its own group below.
    await locator<ConsentRepository>().grant(ConsentPurpose.terms);
  });

  tearDown(() => auth.close());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(BlocProvider.value(value: auth, child: const MaterialApp(home: LoginPage(demoMode: true))));
    await tester.pumpAndSettle();
  }

  testWidgets('phone -> code -> signed in', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '082 123 4567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();

    expect(find.text('We sent a 6-digit code to +27 82 *** 4567.'), findsOneWidget);
    expect(find.text('Resend code in 30s'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(auth.state.isSignedIn, isTrue);
    expect(auth.state.freshSignIn, isTrue);
  });

  testWidgets('an invalid number shows guidance and stays on the phone step', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '011 123 4567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    expect(find.textContaining('valid South African mobile number'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Verify'), findsNothing);
  });

  testWidgets('a wrong code explains and keeps the customer signed out', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '000000');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('not right or has expired'), findsOneWidget);
    expect(auth.state.isSignedIn, isFalse);
  });

  testWidgets('resend is disabled during the countdown and enabled after it', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Resend code in 30s')).onPressed, isNull);
    await tester.pump(const Duration(seconds: 31));
    expect(tester.widget<TextButton>(find.widgetWithText(TextButton, 'Resend code')).onPressed, isNotNull);
  });
  group('terms of service on sign-in', () {
    setUp(() async => locator<ConsentRepository>().clear());

    Future<void> enterCode(WidgetTester tester) async {
      await pumpLogin(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
      await tester.pump();
      await tester.pump();
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500)); // the dialog opens (the Verify spinner keeps animating)
    }

    testWidgets('a returning customer without current terms is asked first; agreeing signs them in and records it', (tester) async {
      await enterCode(tester);
      expect(find.text('Your privacy'), findsOneWidget);
      expect(auth.state.isSignedIn, isFalse, reason: 'the session is not ready before the terms are accepted');

      await tester.tap(find.text('I agree'));
      await tester.pumpAndSettle();
      expect(auth.state.isSignedIn, isTrue);
      expect((await locator<ConsentRepository>().currentConsent(ConsentPurpose.terms)).getOrElse((_) => null), isNotNull);
    });

    testWidgets('declining leaves the customer signed out, with a message', (tester) async {
      await enterCode(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(auth.state.isSignedIn, isFalse);
      expect(find.textContaining('accept the Terms of Service'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Verify'), findsOneWidget, reason: 'still on the code step to try again');
    });

    testWidgets('a new customer (no name yet) is not asked here: the profile page records the terms', (tester) async {
      final repository = _NewCustomerRepository();
      locator.registerSingleton<AuthRepository>(repository);
      await auth.close();
      auth = AuthCubit(repository, sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
      await enterCode(tester);
      expect(find.text('Your privacy'), findsNothing);
      expect(auth.state.isSignedIn, isTrue);
      expect(auth.state.user!.fullName, isEmpty);
    });
  });

  group('biometrics', () {
    testWidgets('are offered while a stored session is locked, and keep being offered after a failed attempt', (tester) async {
      const user = User(id: 'usr_001', fullName: 'Lindiwe Khumalo', mobileNumber: '081 000 0000');
      await locator<SessionStore>().saveUser(user, tenantSlug: 'sentech');
      await locator<SessionStore>().saveBiometricCredential(user.id);
      final biometrics = MockBiometricAuthenticator();
      await auth.close();
      auth = AuthCubit(
        locator(),
        sessionStore: locator(),
        biometrics: biometrics,
        wiper: locator(),
        initial: AuthState.restore(user: user, hasBiometricCredential: true, biometricsAvailable: true),
      );
      await pumpLogin(tester);
      expect(find.text('Use biometrics'), findsOneWidget);
      expect(find.text('Welcome back, Lindiwe'), findsOneWidget);

      biometrics.nextResult = BiometricResult.failed;
      await tester.tap(find.text('Use biometrics'));
      await tester.pumpAndSettle();
      expect(auth.state.status, AuthStatus.failure);
      expect(find.text('Use biometrics'), findsOneWidget);
    });
  });
}
