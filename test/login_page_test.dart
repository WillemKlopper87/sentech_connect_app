import 'dart:async';
import 'package:flutter/services.dart';
import 'package:sentech_connect_app/app/locale_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/dot_grid_panel.dart';
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
  Future<Either<Failure, User>> verifyOtp({
    required OtpChallenge challenge,
    required String code,
  }) async =>
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
  Future<Either<Failure, OtpChallenge>> requestOtp({
    required String phoneNumber,
  }) async => const Left(
    RateLimitedFailure('slow down from the server', Duration(seconds: 90)),
  );
}

class _RateLimitedOnVerifyRepository extends MockAuthRepository {
  _RateLimitedOnVerifyRepository() : super(latency: Duration.zero);

  int requests = 0;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({
    required String phoneNumber,
  }) {
    requests++;
    return super.requestOtp(phoneNumber: phoneNumber);
  }

  @override
  Future<Either<Failure, User>> verifyOtp({
    required OtpChallenge challenge,
    required String code,
  }) async => const Left(
    RateLimitedFailure('slow down from the server', Duration(seconds: 120)),
  );
}

class _PendingRepository extends MockAuthRepository {
  _PendingRepository() : super(latency: Duration.zero);
  int calls = 0;
  Completer<Either<Failure, User>> result = Completer();
  @override
  Future<Either<Failure, User>> verifyOtp({
    required OtpChallenge challenge,
    required String code,
  }) {
    calls++;
    return result.future;
  }
}

void main() {
  setUpAppTests();

  late AuthCubit auth;

  setUp(() {
    locator.registerSingleton<AuthRepository>(
      MockAuthRepository(latency: Duration.zero),
    );
    auth = AuthCubit(
      locator(),
      sessionStore: locator(),
      biometrics: MockBiometricAuthenticator(),
      wiper: locator(),
    );
  });

  tearDown(() => auth.close());

  Future<void> pumpLogin(WidgetTester tester) async {
    await tester.pumpWidget(
      BlocProvider.value(
        value: auth,
        child: const MaterialApp(home: LoginPage(demoMode: true)),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('phone -> code -> signed in', (tester) async {
    await pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '082 123 4567',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();

    expect(
      find.text('We sent a 6-digit code to +27 82 *** 4567.'),
      findsOneWidget,
    );
    expect(find.text('Resend code in 30s'), findsOneWidget);
    expect(find.textContaining('Demo mode'), findsOneWidget);

    await tester.enterText(
      find.widgetWithText(TextField, '6-digit code'),
      '123456',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(auth.state.isSignedIn, isTrue);
    expect(auth.state.freshSignIn, isTrue);
  });

  testWidgets('an invalid number shows guidance and stays on the phone step', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '011 123 4567',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    expect(
      find.textContaining('valid South African mobile number'),
      findsOneWidget,
    );
    expect(find.byType(SnackBar), findsNothing);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
      isNotNull,
    );
    expect(find.widgetWithText(ElevatedButton, 'Verify'), findsNothing);
  });

  testWidgets('a wrong code explains and keeps the customer signed out', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '0821234567',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
    await tester.enterText(
      find.widgetWithText(TextField, '6-digit code'),
      '000000',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
    await tester.pump();
    await tester.pump();
    expect(find.textContaining('not right or has expired'), findsOneWidget);
    expect(auth.state.isSignedIn, isFalse);
  });

  testWidgets('resend is disabled during the countdown and enabled after it', (
    tester,
  ) async {
    await pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '0821234567',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
    expect(
      tester
          .widget<TextButton>(
            find.widgetWithText(TextButton, 'Resend code in 30s'),
          )
          .onPressed,
      isNull,
    );
    await tester.pump(const Duration(seconds: 31));
    expect(
      tester
          .widget<TextButton>(find.widgetWithText(TextButton, 'Resend code'))
          .onPressed,
      isNotNull,
    );
  });
  Future<void> toCodeStep(WidgetTester tester) async {
    await pumpLogin(tester);
    await tester.enterText(
      find.widgetWithText(TextField, 'Mobile number'),
      '0821234567',
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
    await tester.pump();
    await tester.pump();
  }

  group('the code step', () {
    testWidgets('the code field is labelled and focused', (tester) async {
      await toCodeStep(tester);
      final field = tester.widget<TextField>(
        find.widgetWithText(TextField, '6-digit code'),
      );
      expect(field.autofocus, isTrue);
      expect(field.decoration!.labelText, '6-digit code');
    });

    testWidgets(
      'a new customer (no name yet) signs in; the profile step follows via the router',
      (tester) async {
        final repository = _NewCustomerRepository();
        locator.registerSingleton<AuthRepository>(repository);
        await auth.close();
        auth = AuthCubit(
          repository,
          sessionStore: locator(),
          biometrics: MockBiometricAuthenticator(),
          wiper: locator(),
        );
        await toCodeStep(tester);
        await tester.enterText(
          find.widgetWithText(TextField, '6-digit code'),
          '123456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
        await tester.pump();
        await tester.pump();
        expect(auth.state.isSignedIn, isTrue);
        expect(auth.state.user!.fullName, isEmpty);
      },
    );

    testWidgets(
      'a code that was accepted but could not start a session returns to the phone step with a new-code message',
      (tester) async {
        // Another customer's record is on the phone and its wipe fails, so the new sign-in cannot be set up.
        await locator<SessionStore>().saveUser(
          const User(
            id: 'someone-else',
            fullName: 'Old',
            mobileNumber: '+27810000000',
          ),
          tenantSlug: 'sentech',
        );
        await auth.close();
        auth = AuthCubit(
          locator(),
          sessionStore: locator(),
          biometrics: MockBiometricAuthenticator(),
          wiper: _FailingWiper(),
        );
        await toCodeStep(tester);
        await tester.enterText(
          find.widgetWithText(TextField, '6-digit code'),
          '123456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
        await tester.pump();
        await tester.pump();
        expect(find.textContaining('request a new code'), findsOneWidget);
        expect(
          find.widgetWithText(ElevatedButton, 'Send code'),
          findsOneWidget,
          reason: 'back on the phone step',
        );
        expect(auth.state.isSignedIn, isFalse);
      },
    );
  });

  group('rate limiting', () {
    testWidgets(
      'Change number keeps Send code locked for the remaining verify Retry-After',
      (tester) async {
        final repository = _RateLimitedOnVerifyRepository();
        locator.registerSingleton<AuthRepository>(repository);
        await auth.close();
        auth = AuthCubit(
          repository,
          sessionStore: locator(),
          biometrics: MockBiometricAuthenticator(),
          wiper: locator(),
        );
        await toCodeStep(tester);
        await tester.enterText(
          find.widgetWithText(TextField, '6-digit code'),
          '123456',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
        await tester.pump();
        await tester.pump();
        await tester.pump(const Duration(seconds: 60));
        tester
            .state<ScaffoldMessengerState>(find.byType(ScaffoldMessenger))
            .hideCurrentSnackBar();
        await tester.ensureVisible(
          find.widgetWithText(TextButton, 'Change number'),
        );
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
        expect(
          find.text('We sent a 6-digit code to +27 83 *** 4567.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'a 429 shows a localised message and disables Send code for the wait',
      (tester) async {
        final repository = _RateLimitedRepository();
        locator.registerSingleton<AuthRepository>(repository);
        await pumpLogin(tester);
        await tester.enterText(
          find.widgetWithText(TextField, 'Mobile number'),
          '0821234567',
        );
        await tester.tap(find.widgetWithText(ElevatedButton, 'Send code'));
        await tester.pump();
        await tester.pump();

        expect(find.textContaining('Too many attempts'), findsOneWidget);
        expect(
          find.textContaining('slow down from the server'),
          findsNothing,
          reason: 'no raw server text',
        );
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Send code'),
              )
              .onPressed,
          isNull,
        );

        await tester.pump(const Duration(seconds: 91));
        expect(
          tester
              .widget<ElevatedButton>(
                find.widgetWithText(ElevatedButton, 'Send code'),
              )
              .onPressed,
          isNotNull,
        );
      },
    );

    testWidgets('a 429 on verify disables Verify and Resend', (tester) async {
      await auth.close();
      auth = AuthCubit(
        _RateLimitedOnVerifyRepository(),
        sessionStore: locator(),
        biometrics: MockBiometricAuthenticator(),
        wiper: locator(),
      );
      await toCodeStep(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        '123456',
      );
      await tester.tap(find.widgetWithText(ElevatedButton, 'Verify'));
      await tester.pump();
      await tester.pump();
      expect(find.textContaining('Too many attempts'), findsOneWidget);
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Verify'),
            )
            .onPressed,
        isNull,
      );
      expect(find.textContaining('Resend code in'), findsOneWidget);

      await tester.pump(const Duration(seconds: 121));
      expect(
        tester
            .widget<ElevatedButton>(
              find.widgetWithText(ElevatedButton, 'Verify'),
            )
            .onPressed,
        isNotNull,
      );
    });
  });

  testWidgets('unknown customer sees Hello and a 96px decorative panel', (
    tester,
  ) async {
    await pumpLogin(tester);
    expect(find.text('Hello!'), findsOneWidget);
    expect(find.text('Welcome back'), findsNothing);
    expect(tester.widget<DotGridPanel>(find.byType(DotGridPanel)).height, 96);
    expect(
      tester.widget<TextField>(find.byType(TextField)).decoration!.border,
      isA<OutlineInputBorder>(),
    );
  });

  Future<_PendingRepository> pendingCode(WidgetTester tester) async {
    final repo = _PendingRepository();
    locator.registerSingleton<AuthRepository>(repo);
    await auth.close();
    auth = AuthCubit(
      repo,
      sessionStore: locator(),
      biometrics: MockBiometricAuthenticator(),
      wiper: locator(),
    );
    await toCodeStep(tester);
    return repo;
  }

  testWidgets(
    'six digits auto-submit once despite manual confirm and repeated edits',
    (tester) async {
      final repo = await pendingCode(tester);
      final code = find.widgetWithText(TextField, '6-digit code');
      expect(
        tester.widget<TextField>(code).autofillHints,
        contains(AutofillHints.oneTimeCode),
      );
      await tester.enterText(code, '123456');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();
      expect(repo.calls, 1);
      expect(
        tester.widget<ElevatedButton>(find.byType(ElevatedButton)).onPressed,
        isNull,
      );
      expect(
        tester
            .widget<TextButton>(find.widgetWithText(TextButton, 'Paste code'))
            .onPressed,
        isNull,
      );
      await tester.enterText(code, '654321');
      expect(repo.calls, 1);
      repo.result.complete(
        const Left(ValidationFailure('wrong', 'otp_invalid')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SnackBar), findsNothing);
      repo.result = Completer();
      await tester.enterText(code, '234567');
      await tester.pump();
      expect(repo.calls, 2);
      repo.result.complete(
        const Right(
          User(id: 'usr_001', fullName: 'Name', mobileNumber: '+27821234567'),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(code, '345678');
      expect(
        repo.calls,
        2,
        reason: 'a verified challenge cannot be submitted again',
      );
    },
  );

  for (final input in [
    '1234567',
    'Call 0821234567. Code 123456',
    '123456 or 654321',
  ]) {
    testWidgets('field paste rejects ambiguous input: $input', (tester) async {
      final repo = await pendingCode(tester);
      await tester.enterText(
        find.widgetWithText(TextField, '6-digit code'),
        input,
      );
      await tester.pump();
      expect(repo.calls, 0);
      expect(
        tester.widget<TextField>(find.byType(TextField)).decoration!.errorText,
        isNotNull,
      );
    });
  }

  testWidgets(
    'explicit paste normalizes formatted six digits and submits once',
    (tester) async {
      final repo = await pendingCode(tester);
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async =>
                call.method == 'Clipboard.getData' ? {'text': '123 456'} : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.ensureVisible(find.text('Paste code'));
      await tester.tap(find.text('Paste code'));
      await tester.pump();
      expect(repo.calls, 1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        '123456',
      );
      repo.result.complete(
        const Left(ValidationFailure('wrong', 'otp_invalid')),
      );
      await tester.pumpAndSettle();
    },
  );

  for (final change in [
    'number',
    'resend',
    'busy',
    'verified',
    'locked',
    'disposed',
  ]) {
    testWidgets('clipboard completion is ignored after $change', (
      tester,
    ) async {
      final repo = await pendingCode(tester);
      final clipboard = Completer<Object?>();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            SystemChannels.platform,
            (call) async =>
                call.method == 'Clipboard.getData' ? clipboard.future : null,
          );
      addTearDown(
        () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, null),
      );
      await tester.ensureVisible(find.text('Paste code'));
      await tester.tap(find.text('Paste code'));
      await tester.pump();
      if (change == 'number') {
        await tester.tap(find.text('Change number'));
      } else if (change == 'resend') {
        await tester.pump(const Duration(seconds: 31));
        await tester.tap(find.text('Resend code'));
      } else if (change == 'disposed') {
        await tester.pumpWidget(const SizedBox());
      } else {
        await tester.enterText(find.byType(TextField), '123456');
        await tester.pump();
        if (change == 'verified') {
          repo.result.complete(
            const Right(
              User(
                id: 'usr_001',
                fullName: 'Name',
                mobileNumber: '+27821234567',
              ),
            ),
          );
        }
        if (change == 'locked') {
          repo.result.complete(
            const Left(RateLimitedFailure('wait', Duration(seconds: 120))),
          );
        }
      }
      await tester.pump();
      final calls = repo.calls;
      clipboard.complete({'text': '654321'});
      await tester.pump();
      await tester.pump();
      expect(repo.calls, calls);
      if (change == 'number') {
        expect(find.widgetWithText(TextField, 'Mobile number'), findsOneWidget);
      }
      if (change == 'resend') {
        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          isEmpty,
        );
      }
      if (change == 'busy') {
        repo.result.complete(
          const Left(ValidationFailure('wrong', 'otp_invalid')),
        );
      }
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    });
  }

  testWidgets('explicit paste rejects multiple codes', (tester) async {
    final repo = await pendingCode(tester);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          SystemChannels.platform,
          (call) async => call.method == 'Clipboard.getData'
              ? {'text': '123456 654321'}
              : null,
        );
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await tester.ensureVisible(find.text('Paste code'));
    await tester.tap(find.text('Paste code'));
    await tester.pump();
    expect(repo.calls, 0);
    expect(find.text('Paste only the 6-digit code.'), findsOneWidget);
  });

  testWidgets(
    'language choice updates login immediately and follows device default',
    (tester) async {
      final locale = LocaleCubit(save: (_) async {});
      addTearDown(locale.close);
      await tester.pumpWidget(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: auth),
            BlocProvider.value(value: locale),
          ],
          child: BlocBuilder<LocaleCubit, Locale?>(
            builder: (context, selected) => MaterialApp(
              locale: selected,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const LoginPage(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('English'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('isiZulu').last);
      await tester.pumpAndSettle();
      expect(locale.state, const Locale('zu'));
      expect(
        find.text(lookupAppLocalizations(const Locale('zu')).loginSendCode),
        findsOneWidget,
      );
      await tester.tap(find.text('isiZulu'));
      await tester.pumpAndSettle();
      await tester.tap(
        find.text(
          lookupAppLocalizations(const Locale('zu')).accountLanguageSystem,
        ),
      );
      await tester.pumpAndSettle();
      expect(locale.state, isNull);
    },
  );

  group('biometrics', () {
    testWidgets(
      'are offered while a stored session is locked, and keep being offered after a failed attempt',
      (tester) async {
        const user = User(
          id: 'usr_001',
          fullName: 'Lindiwe Khumalo',
          mobileNumber: '081 000 0000',
        );
        await locator<SessionStore>().saveUser(user, tenantSlug: 'sentech');
        await locator<SessionStore>().saveBiometricCredential(user.id);
        final biometrics = MockBiometricAuthenticator();
        await auth.close();
        auth = AuthCubit(
          locator(),
          sessionStore: locator(),
          biometrics: biometrics,
          wiper: locator(),
          initial: AuthState.restore(
            user: user,
            hasBiometricCredential: true,
            biometricsAvailable: true,
          ),
        );
        await pumpLogin(tester);
        expect(find.text('Use biometrics'), findsOneWidget);
        expect(find.text('Welcome back, Lindiwe'), findsOneWidget);

        biometrics.nextResult = BiometricResult.failed;
        await tester.tap(find.text('Use biometrics'));
        await tester.pumpAndSettle();
        expect(auth.state.status, AuthStatus.failure);
        expect(find.text('Use biometrics'), findsOneWidget);
      },
    );
  });
}
