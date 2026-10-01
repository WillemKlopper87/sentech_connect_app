import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/legal_gate_page.dart';

import 'helpers/test_setup.dart';

const _user = User(id: 'usr_001', fullName: 'Lindiwe Khumalo', mobileNumber: '+27810000000');

class _FlakyConsents extends LocalConsentRepository {
  _FlakyConsents(super.store);

  bool offline = false;

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose) async =>
      offline ? const Left(NetworkFailure()) : super.currentConsent(purpose);

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) async =>
      offline ? const Left(NetworkFailure()) : super.grant(purpose);
}

void main() {
  setUpAppTests();

  late _FlakyConsents consents;
  late AuthCubit auth;

  setUp(() {
    consents = _FlakyConsents(InMemorySecureStore());
    auth = AuthCubit(
      locator(),
      sessionStore: locator(),
      biometrics: MockBiometricAuthenticator(),
      wiper: locator(),
      initial: const AuthState(status: AuthStatus.success, user: _user),
      consents: consents,
    );
  });

  tearDown(() => auth.close());

  Future<void> pumpGate(WidgetTester tester) async {
    await tester.pumpWidget(BlocProvider.value(value: auth, child: const MaterialApp(home: LegalGatePage())));
    await tester.pumpAndSettle();
  }

  testWidgets('without current consent it asks; I agree records terms and privacy', (tester) async {
    await pumpGate(tester);
    expect(find.textContaining('accept the Terms of Service'), findsOneWidget);
    expect(auth.state.legal, LegalStatus.required);

    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(auth.state.legal, LegalStatus.accepted);
    for (final purpose in [ConsentPurpose.terms, ConsentPurpose.privacy]) {
      expect((await consents.currentConsent(purpose)).getOrElse((_) => null), isNotNull, reason: '$purpose');
    }
  });

  testWidgets('a failed check is shown as a failure with Retry, not as a request to accept', (tester) async {
    consents.offline = true;
    await pumpGate(tester);
    expect(auth.state.legal, LegalStatus.unavailable);
    expect(find.textContaining('could not check the Terms of Service'), findsOneWidget);
    expect(find.text('I agree'), findsNothing);

    consents.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(find.text('I agree'), findsOneWidget);
  });

  testWidgets('someone who already agreed is not asked, even after a failed attempt', (tester) async {
    await consents.grant(ConsentPurpose.terms);
    await consents.grant(ConsentPurpose.privacy);
    consents.offline = true;
    await pumpGate(tester);
    expect(find.text('I agree'), findsNothing);

    consents.offline = false;
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();
    expect(auth.state.legal, LegalStatus.accepted);
  });

  testWidgets('a recording that fails offers Retry and keeps the customer signed in', (tester) async {
    await pumpGate(tester);
    consents.offline = true;
    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();
    expect(auth.state.legal, LegalStatus.unavailable);
    expect(auth.state.isSignedIn, isTrue);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Sign out leaves the session', (tester) async {
    await pumpGate(tester);
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();
    expect(auth.state.isSignedIn, isFalse);
  });
}
