import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/auth/presentation/pages/login_page.dart';

import 'helpers/test_setup.dart';

/// A first-time customer: the platform creates the account on the first verified code, with no name yet.
class _NewCustomerRepository extends MockAuthRepository {
  _NewCustomerRepository() : super(latency: Duration.zero);

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async =>
      Right(User(id: 'new-1', fullName: '', mobileNumber: challenge.phoneE164));
}

class _FailingWiper implements PersonalDataWiper {
  @override
  Future<void> wipeOnLogout() async => throw StateError('disk');

  @override
  Future<void> wipeEverything() async => throw StateError('disk');
}

class _RateLimitedRepository extends MockAuthRepository {
  _RateLimitedRepository() : super(latency: Duration.zero);

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) async =>
      const Left(RateLimitedFailure('slow down from the server', Duration(seconds: 90)));
}

class _RateLimitedOnVerifyRepository extends MockAuthRepository {
  _RateLimitedOnVerifyRepository() : super(latency: Duration.zero);

  int requests = 0;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) {
    requests++;
    return super.requestOtp(phoneNumber: phoneNumber);
  }

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async =>
      const Left(RateLimitedFailure('slow down from the server', Duration(seconds: 120)));
}

void main() {
  setUpAppTests();

  late AuthCubit auth;

  setUp(() {
    locator.registerSingleton<AuthRepository>(MockAuthRepository(latency: Duration.zero));
    auth = AuthCubit(locator(), sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
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
  Future<void> toCodeStep(WidgetTester tester) async {
    await pumpLogin(tester);
    await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
  }

  group('the code step', () {
    testWidgets('the code field is labelled and focused', (tester) async {
      await toCodeStep(tester);
      final field = tester.widget<TextField>(find.widgetWithText(TextField, '6-digit code'));
      expect(field.autofocus, isTrue);
      expect(field.decoration!.labelText, '6-digit code');
    });

    testWidgets('a new customer (no name yet) signs in; the profile step follows via the router', (tester) async {
      final repository = _NewCustomerRepository();
      locator.registerSingleton<AuthRepository>(repository);
      await auth.close();
      auth = AuthCubit(repository, sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
      await toCodeStep(tester);
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump();
      expect(auth.state.isSignedIn, isTrue);
      expect(auth.state.user!.fullName, isEmpty);
    });

    testWidgets('a code that was accepted but could not start a session returns to the phone step with a new-code message', (tester) async {
      // Another customer's record is on the phone and its wipe fails, so the new sign-in cannot be set up.
      await locator<SessionStore>().saveUser(const User(id: 'someone-else', fullName: 'Old', mobileNumber: '+27810000000'), tenantSlug: 'sentech');
      await auth.close();
      auth = AuthCubit(locator(), sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: _FailingWiper());
      await toCodeStep(tester);
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('request a new code'), findsOneWidget);
      expect(find.widgetWithText(ElevatedButton, 'Send code'), findsOneWidget, reason: 'back on the phone step');
      expect(auth.state.isSignedIn, isFalse);
    });
  });

  group('rate limiting', () {
    testWidgets('Change number keeps Send code locked for the remaining verify Retry-After', (tester) async {
      final repository = _RateLimitedOnVerifyRepository();
      locator.registerSingleton<AuthRepository>(repository);
      await auth.close();
      auth = AuthCubit(repository, sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
      await toCodeStep(tester);
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(seconds: 60));
      tester.state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger)).hideCurrentSnackBar();
      await tester.ensureVisible(find.widgetWithText(TextButton, 'Change number'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(TextButton, 'Change number'));
      await tester.pump();

      final phone = find.widgetWithText(TextField, 'Mobile number');
      final send = find.widgetWithText(ElevatedButton, 'Send code');
      expect(tester.widget<TextField>(phone).controller!.text, '0821234567');
      expect(tester.widget<ElevatedButton>(send).onPressed, isNull);
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump();
      expect(repository.requests, 1);
      await tester.enterText(phone, '0831234567');
      expect(tester.widget<ElevatedButton>(send).onPressed, isNull);
      await tester.pump(const Duration(seconds: 59));
      expect(tester.widget<ElevatedButton>(send).onPressed, isNull);
      await tester.pump(const Duration(seconds: 1));
      expect(tester.widget<ElevatedButton>(send).onPressed, isNotNull);
      await tester.tap(send);
      await tester.pump();
      await tester.pump();
      expect(repository.requests, 2);
      expect(find.text('We sent a 6-digit code to +27 83 *** 4567.'), findsOneWidget);
    });

    testWidgets('a 429 shows a localised message and disables Send code for the wait', (tester) async {
      final repository = _RateLimitedRepository();
      locator.registerSingleton<AuthRepository>(repository);
      await pumpLogin(tester);
      await tester.enterText(find.widgetWithText(TextField, 'Mobile number'), '0821234567');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
      await tester.pump();
      await tester.pump();

      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(find.textContaining('slow down from the server'), findsNothing, reason: 'no raw server text');
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Send code')).onPressed, isNull);

      await tester.pump(const Duration(seconds: 91));
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Send code')).onPressed, isNotNull);
    });

    testWidgets('a 429 on verify disables Verify and Resend', (tester) async {
      await auth.close();
      auth = AuthCubit(_RateLimitedOnVerifyRepository(), sessionStore: locator(), biometrics: MockBiometricAuthenticator(), wiper: locator());
      await toCodeStep(tester);
      await tester.enterText(find.widgetWithText(TextField, '6-digit code'), '123456');
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verify')).onPressed, isNull);
      expect(find.textContaining('Resend code in'), findsOneWidget);

      await tester.pump(const Duration(seconds: 121));
      expect(tester.widget<ElevatedButton>(find.widgetWithText(ElevatedButton, 'Verify')).onPressed, isNotNull);
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
