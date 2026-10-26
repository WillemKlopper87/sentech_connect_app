import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

const _user = User(id: 'c1', fullName: 'Lindiwe Khumalo', mobileNumber: '+27810000000');

class _RecordingWiper implements PersonalDataWiper {
  int logoutWipes = 0;
  int fullWipes = 0;

  Future<void> Function()? onWipe;

  @override
  Future<void> wipeOnLogout() async {
    logoutWipes++;
    await onWipe?.call();
  }

  @override
  Future<void> wipeEverything() async => fullWipes++;
}

class _FakeAuthRepository extends MockAuthRepository {
  _FakeAuthRepository() : super(latency: Duration.zero);

  int logOuts = 0;
  int discards = 0;
  int resumes = 0;
  Future<void>? verifyGate;
  Either<Failure, User>? verifyResult;
  bool matches = true;
  Future<void>? resumeGate;
  Object? logOutError;
  Either<Failure, User> resumeResult = const Right(_user);

  @override
  Future<Either<Failure, User>> resumeSession() async {
    resumes++;
    await resumeGate;
    return resumeResult;
  }

  @override
  Future<Either<Failure, User>> verifyOtp({required OtpChallenge challenge, required String code}) async {
    await verifyGate;
    return verifyResult ?? super.verifyOtp(challenge: challenge, code: code);
  }

  @override
  Future<void> discardLocalSession() async => discards++;

  @override
  Future<bool> sessionMatches({required String tenantSlug, required User user}) async => matches;

  @override
  Future<void> logOut() async {
    logOuts++;
    final error = logOutError;
    if (error != null) throw error;
  }
}

class _FakeConsents implements ConsentRepository {
  final granted = <ConsentPurpose>{};
  bool readFails = false;
  bool grantFails = false;
  int grants = 0;

  @override
  Future<Either<Failure, ConsentRecord?>> currentConsent(ConsentPurpose purpose) async {
    if (readFails) return const Left(NetworkFailure());
    return Right(granted.contains(purpose)
        ? ConsentRecord(purpose: purpose, policyVersion: 'v1', grantedAt: DateTime.utc(2026, 10, 1))
        : null);
  }

  @override
  Future<Either<Failure, ConsentRecord>> grant(ConsentPurpose purpose) async {
    grants++;
    if (grantFails) return const Left(NetworkFailure());
    granted.add(purpose);
    return Right(ConsentRecord(purpose: purpose, policyVersion: 'v1', grantedAt: DateTime.utc(2026, 10, 1)));
  }

  @override
  Future<Either<Failure, Unit>> withdraw(ConsentPurpose purpose) async {
    granted.remove(purpose);
    return const Right(unit);
  }

  @override
  Future<List<ConsentRecord>> unsyncedRecords() async => const [];

  @override
  Future<void> markSynced(Iterable<ConsentRecord> records) async {}

  @override
  Future<void> clear() async => granted.clear();
}

void main() {
  late InMemorySecureStore secureStore;
  late SecureSessionStore sessionStore;
  late MockBiometricAuthenticator biometrics;
  late _RecordingWiper wiper;
  late _FakeAuthRepository repo;
  late SessionEvents events;

  setUp(() {
    secureStore = InMemorySecureStore();
    sessionStore = SecureSessionStore(secureStore);
    biometrics = MockBiometricAuthenticator();
    wiper = _RecordingWiper();
    repo = _FakeAuthRepository();
    events = SessionEvents();
  });

  AuthCubit build({AuthState initial = const AuthState()}) => AuthCubit(
        repo,
        sessionStore: sessionStore,
        biometrics: biometrics,
        wiper: wiper,
        initial: initial,
        sessionExpired: events.expired,
        providerUnavailable: events.providerUnavailable,
      );

  Future<AuthCubit> lockedCubit() async {
    await sessionStore.saveUser(_user, tenantSlug: 'sentech');
    await sessionStore.saveBiometricCredential(_user.id);
    return build(initial: AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: true));
  }

  test('biometrics are not offered before any session was established', () async {
    final cubit = build();
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
    await cubit.close();
  });

  test('biometric unlock is refused without a stored session, without prompting', () async {
    final cubit = build();
    await cubit.logInWithBiometrics(reason: 'test');
    expect(cubit.state.status, AuthStatus.failure);
    expect(biometrics.authenticateCalls, 0);
    await cubit.close();
  });

  test('signing in persists the session securely and enables biometrics', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.freshSignIn, isTrue);
    expect(await sessionStore.loadUser(), _user);
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isTrue);
    await cubit.close();
  });

  test('biometrics are hidden when nothing is enrolled on the device', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    biometrics.nextAvailability = BiometricAvailability.notEnrolled;
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
    await cubit.close();
  });

  test('a restored session without usable biometrics opens straight away', () {
    expect(AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: false).isSignedIn, isTrue);
    expect(AuthState.restore(user: null, hasBiometricCredential: true, biometricsAvailable: true).isSignedIn, isFalse);
  });

  test('a restored session with biometrics starts locked and unlocks after the biometric check', () async {
    final cubit = await lockedCubit();
    expect(cubit.state.status, AuthStatus.locked);
    expect(cubit.state.isSignedIn, isFalse);
    await cubit.logInWithBiometrics(reason: 'test');
    expect(biometrics.authenticateCalls, 1);
    expect(repo.resumes, 1);
    expect(cubit.state.isSignedIn, isTrue);
    expect(cubit.state.freshSignIn, isFalse);
    await cubit.close();
  });

  for (final (result, issue) in [
    (BiometricResult.cancelled, BiometricIssue.cancelled),
    (BiometricResult.notEnrolled, BiometricIssue.notEnrolled),
    (BiometricResult.unavailable, BiometricIssue.unavailable),
    (BiometricResult.lockedOut, BiometricIssue.lockedOut),
    (BiometricResult.permanentlyLockedOut, BiometricIssue.permanentlyLockedOut),
    (BiometricResult.failed, BiometricIssue.failed),
  ]) {
    test('biometric $result leaves the session locked with $issue and never resumes it', () async {
      final cubit = await lockedCubit();
      biometrics.nextResult = result;
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.biometricIssue, issue);
      expect(repo.resumes, 0);
      await cubit.close();
    });
  }

  test('a revoked session found at unlock is forgotten, with a message', () async {
    repo.resumeResult = const Left(UnauthorizedFailure());
    final cubit = await lockedCubit();
    await cubit.logInWithBiometrics(reason: 'test');
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.errorMessage, 'Your session has ended. Sign in again.');
    expect(cubit.state.biometricsReady, isFalse);
    expect(await sessionStore.loadBiometricCredential(), isNull);
    expect(wiper.logoutWipes, 1);
    await cubit.close();
  });

  test('an offline unlock keeps the stored session and the biometric credential', () async {
    repo.resumeResult = const Left(NetworkFailure());
    final cubit = await lockedCubit();
    await cubit.logInWithBiometrics(reason: 'test');
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.errorMessage, const NetworkFailure().message);
    expect(await sessionStore.loadBiometricCredential(), _user.id);
    expect(wiper.logoutWipes, 0);
    await cubit.close();
  });

  test('logout revokes server-side, forgets the biometric credential and wipes personal data', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    await cubit.logOut();
    expect(repo.logOuts, 1);
    expect(wiper.logoutWipes, 1);
    expect(await sessionStore.loadUser(), isNull);
    expect(await sessionStore.loadBiometricCredential(), isNull);
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
    await cubit.close();
  });

  test('logout still forgets and wipes everything when revoking fails, then reports it', () async {
    repo.logOutError = StateError('keystore');
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    await expectLater(cubit.logOut(), throwsStateError);
    expect(cubit.state.isSignedIn, isFalse);
    expect(await sessionStore.loadUser(), isNull);
    expect(await sessionStore.loadBiometricCredential(), isNull);
    expect(wiper.logoutWipes, 1);
    await cubit.close();
  });

  group('a different customer signing in over a stored session (R-m9)', () {
    const other = User(id: 'c2', fullName: 'Sipho Dlamini', mobileNumber: '+27820000000');

    test("the previous customer's local data is wiped BEFORE the new session is stored", () async {
      final cubit = await lockedCubit();
      User? storedWhenWiped;
      wiper.onWipe = () async => storedWhenWiped = await sessionStore.loadUser();
      await cubit.signedIn(other, fresh: true);
      expect(wiper.logoutWipes, 1);
      expect(storedWhenWiped, _user, reason: 'wiped while the old record was still there, i.e. before saving the new one');
      expect(await sessionStore.loadUser(), other);
      expect(await sessionStore.loadBiometricCredential(), other.id);
      expect(cubit.state.user, other);
      await cubit.close();
    });

    test('the same customer unlocking again wipes nothing', () async {
      final cubit = await lockedCubit();
      await cubit.signedIn(_user, fresh: false);
      expect(wiper.logoutWipes, 0);
      await cubit.close();
    });

    test('a wipe failure stops the new sign-in (nothing of the old customer may carry over)', () async {
      final cubit = await lockedCubit();
      wiper.onWipe = () async => throw StateError('disk');
      await expectLater(cubit.signedIn(other, fresh: true), throwsStateError);
      expect(cubit.state.isSignedIn, isFalse);
      expect(await sessionStore.loadUser(), _user);
      expect(repo.discards, 1, reason: "the new customer's tokens must not stay next to the old record (N1)");
      await cubit.close();
    });
  });

  group('a resumed session must be the customer this device holds (N1)', () {
    const other = User(id: 'c2', fullName: 'Sipho Dlamini', mobileNumber: '+27820000000');

    test('a resumed user that differs from the biometric credential is signed out and wiped', () async {
      repo.resumeResult = const Right(other);
      final cubit = await lockedCubit();
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.status, AuthStatus.failure);
      expect(await sessionStore.loadUser(), isNull);
      expect(await sessionStore.loadBiometricCredential(), isNull);
      expect(wiper.logoutWipes, 1);
      expect(repo.logOuts, 1, reason: 'the foreign session is revoked too');
      await cubit.close();
    });

    test('a resumed user that differs from the stored record is signed out and wiped', () async {
      await sessionStore.saveUser(other, tenantSlug: 'sentech'); // record of c2 ...
      await sessionStore.saveBiometricCredential(_user.id); // ... marker of c1
      final cubit = build(initial: AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: true));
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isFalse);
      expect(await sessionStore.loadUser(), isNull);
      expect(wiper.logoutWipes, 1);
      await cubit.close();
    });

    test('the matching customer still unlocks', () async {
      final cubit = await lockedCubit();
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isTrue);
      expect(wiper.logoutWipes, 0);
      await cubit.close();
    });
  });

  group('signInWithOtp: verify and sign-in are one operation', () {
    const challenge = OtpChallenge(id: 'ch-1', phoneE164: '+27810000000', expiresIn: Duration(minutes: 5), binding: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb');
    const sipho = User(id: 'c2', fullName: 'Sipho', mobileNumber: '+27820000000');

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await Future<void>.delayed(Duration.zero);
      }
    }

    test('a correct code signs the customer in (fresh) and returns the user', () async {
      final cubit = build();
      final result = await cubit.signInWithOtp(challenge: challenge, code: '123456');
      expect(result.isRight(), isTrue);
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.freshSignIn, isTrue);
      expect(await sessionStore.loadUser(), isNotNull);
      await cubit.close();
    });

    test('a wrong code leaves the customer signed out and stores nothing', () async {
      final cubit = build();
      final result = await cubit.signInWithOtp(challenge: challenge, code: MockAuthRepository.rejectedDemoCode);
      expect((result.match((f) => f, (_) => null)! as ValidationFailure).code, 'otp_invalid');
      expect(cubit.state.isSignedIn, isFalse);
      expect(await sessionStore.loadUser(), isNull);
      await cubit.close();
    });

    test('a sign-in whose wipe fails reports a failure and drops the new tokens', () async {
      final cubit = await lockedCubit();
      repo.verifyResult = const Right(sipho);
      wiper.onWipe = () async => throw StateError('disk');
      final result = await cubit.signInWithOtp(challenge: challenge, code: '123456');
      expect(result.match((f) => f, (_) => null), isA<SessionSetupFailure>());
      expect(cubit.state.isSignedIn, isFalse);
      expect(repo.logOuts, greaterThanOrEqualTo(1), reason: "the new session's refresh token is revoked before the local tokens go");
      expect(repo.discards, greaterThanOrEqualTo(1));
      await cubit.close();
    });

    test('a session-expired event during the sign-in is ignored: it belongs to the replaced session (N2)', () async {
      final cubit = build();
      await cubit.signedIn(_user, fresh: true);
      final gate = Completer<void>();
      repo.verifyGate = gate.future;
      repo.verifyResult = const Right(sipho);
      final pending = cubit.signInWithOtp(challenge: challenge, code: '123456');
      events.sessionExpired();
      await settle();
      gate.complete();
      await pending;
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.user!.id, 'c2');
      expect(repo.logOuts, 0, reason: 'the expiry must not have signed the new session out');
      await cubit.close();
    });

    test('expiry events count again once the sign-in is over', () async {
      final cubit = build();
      await cubit.signInWithOtp(challenge: challenge, code: '123456');
      events.sessionExpired();
      await settle();
      expect(cubit.state.isSignedIn, isFalse);
      await cubit.close();
    });
  });

  group('legal consent gate (terms + privacy) for every kind of session', () {
    late _FakeConsents consents;

    setUp(() => consents = _FakeConsents());

    AuthCubit withConsents({AuthState initial = const AuthState()}) => AuthCubit(
          repo,
          sessionStore: sessionStore,
          biometrics: biometrics,
          wiper: wiper,
          initial: initial,
          sessionExpired: events.expired,
          consents: consents,
        );

    test('without a consent repository nothing is gated', () async {
      final cubit = build();
      await cubit.signedIn(_user, fresh: true);
      expect(cubit.state.legal, LegalStatus.accepted);
      await cubit.close();
    });

    test('an interactive sign-in starts unchecked; no consent on record means required', () async {
      final cubit = withConsents();
      await cubit.signedIn(_user, fresh: true);
      expect(cubit.state.legal, LegalStatus.unchecked);
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.required);
      await cubit.close();
    });

    test('both terms and privacy must be current; then it is accepted', () async {
      final cubit = withConsents();
      await cubit.signedIn(_user, fresh: true);
      consents.granted.add(ConsentPurpose.terms);
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.required, reason: 'privacy missing');
      consents.granted.add(ConsentPurpose.privacy);
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.accepted);
      await cubit.close();
    });

    test('a session restored at launch (cold start) is gated until it is checked', () async {
      final cubit = withConsents(initial: const AuthState(status: AuthStatus.success, user: _user));
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.legal, LegalStatus.unchecked);
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.required);
      await cubit.close();
    });

    test('a biometric unlock is gated too: a session without current consent lands on the consent step', () async {
      await sessionStore.saveUser(_user, tenantSlug: 'sentech');
      await sessionStore.saveBiometricCredential(_user.id);
      final cubit = withConsents(initial: AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: true));
      expect(cubit.state.status, AuthStatus.locked);
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isTrue);
      expect(cubit.state.legal, LegalStatus.unchecked);
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.required);
      await cubit.close();
    });

    test('a failed lookup is unavailable (retry), never required: someone who agreed is not re-asked', () async {
      consents.granted.addAll([ConsentPurpose.terms, ConsentPurpose.privacy]);
      consents.readFails = true;
      final cubit = withConsents(initial: const AuthState(status: AuthStatus.success, user: _user));
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.unavailable);
      consents.readFails = false;
      await cubit.checkLegal();
      expect(cubit.state.legal, LegalStatus.accepted);
      await cubit.close();
    });

    test('agreeing records terms and privacy; a failed recording is unavailable and can be retried', () async {
      final cubit = withConsents();
      await cubit.signedIn(_user, fresh: true);
      consents.grantFails = true;
      await cubit.acceptLegal();
      expect(cubit.state.legal, LegalStatus.unavailable);
      consents.grantFails = false;
      await cubit.acceptLegal();
      expect(cubit.state.legal, LegalStatus.accepted);
      expect(consents.granted, {ConsentPurpose.terms, ConsentPurpose.privacy});
      await cubit.close();
    });

    test('a double tap on I agree records once', () async {
      final cubit = withConsents();
      await cubit.signedIn(_user, fresh: true);
      await Future.wait([cubit.acceptLegal(), cubit.acceptLegal()]);
      expect(consents.grants, 2, reason: 'terms + privacy, once');
      await cubit.close();
    });

    test('signing out while the check runs ignores its answer', () async {
      final cubit = withConsents();
      await cubit.signedIn(_user, fresh: true);
      final check = cubit.checkLegal();
      await cubit.logOut();
      await check;
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.legal, LegalStatus.accepted);
      await cubit.close();
    });

    test('the profile step that just recorded the consents opens the app straight away', () async {
      final cubit = withConsents();
      await cubit.signedIn(const User(id: 'c1', fullName: '', mobileNumber: '+27810000000'), fresh: true);
      await cubit.profileUpdated(_user, legalAccepted: true);
      expect(cubit.state.legal, LegalStatus.accepted);
      await cubit.close();
    });
  });

  group('ensureSessionMatches (tenant- and customer-bound session, R-m8)', () {
    test('a matching session stays signed in', () async {
      final cubit = build();
      await cubit.signedIn(_user, fresh: true);
      await cubit.ensureSessionMatches('sentech');
      expect(cubit.state.isSignedIn, isTrue);
      expect(wiper.logoutWipes, 0);
      await cubit.close();
    });

    test('a different active tenant signs the customer out and wipes', () async {
      final cubit = build();
      await cubit.signedIn(_user, fresh: true);
      await cubit.ensureSessionMatches('acme-wifi');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.user, isNull);
      expect(wiper.logoutWipes, 1);
      expect(repo.logOuts, 1);
      expect(await sessionStore.loadUser(), isNull);
      await cubit.close();
    });

    test('tokens that do not belong to this tenant/customer sign the customer out', () async {
      final cubit = build();
      await cubit.signedIn(_user, fresh: true);
      repo.matches = false;
      await cubit.ensureSessionMatches('sentech');
      expect(cubit.state.isSignedIn, isFalse);
      expect(wiper.logoutWipes, 1);
      await cubit.close();
    });

    test('a stored user without a binding (mock-phase build) is signed out, also when locked', () async {
      await secureStore.write('session_user', '{"id":"c1","fullName":"Lindiwe Khumalo","mobileNumber":"+27810000000"}');
      final cubit = build(initial: AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: true));
      expect(cubit.state.status, AuthStatus.locked);
      await cubit.ensureSessionMatches('sentech');
      expect(cubit.state.status, AuthStatus.initial);
      expect(cubit.state.user, isNull);
      expect(wiper.logoutWipes, 1);
      await cubit.close();
    });

    test('a record bound to another customer id is signed out', () async {
      await secureStore.write(
        'session_user',
        '{"id":"c1","fullName":"x","mobileNumber":"y","tenantSlug":"sentech","customerId":"someone-else"}',
      );
      final cubit = build(initial: const AuthState(status: AuthStatus.success, user: _user));
      await cubit.ensureSessionMatches('sentech');
      expect(cubit.state.isSignedIn, isFalse);
      await cubit.close();
    });

    test('nobody signed in: nothing to do', () async {
      final cubit = build();
      await cubit.ensureSessionMatches('acme-wifi');
      expect(wiper.logoutWipes, 0);
      expect(repo.logOuts, 0);
      await cubit.close();
    });

    test('the session is recorded under the ACTIVE tenant', () async {
      final cubit = AuthCubit(
        repo,
        sessionStore: sessionStore,
        biometrics: biometrics,
        wiper: wiper,
        sessionExpired: events.expired,
        activeTenantSlug: () => 'acme-wifi',
      );
      await cubit.signedIn(_user, fresh: true);
      expect(await sessionStore.loadBinding(), const SessionBinding(tenantSlug: 'acme-wifi', customerId: 'c1'));
      await cubit.close();
    });
  });

  test('a logout that races the unlock is not undone when the session finally resumes', () async {
    final gate = Completer<void>();
    repo.resumeGate = gate.future;
    final cubit = await lockedCubit();
    final unlocking = cubit.logInWithBiometrics(reason: 'test');
    for (var i = 0; i < 10; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    await cubit.logOut();
    gate.complete();
    await unlocking;
    expect(cubit.state.isSignedIn, isFalse);
    expect(await sessionStore.loadUser(), isNull, reason: 'the session must not be re-saved after logout');
    await cubit.close();
  });

  test('account deletion also revokes and leaves secure storage empty', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    await cubit.signOutAndWipeEverything();
    expect(repo.logOuts, 1);
    expect(wiper.fullWipes, 1);
    expect(secureStore.snapshot, isEmpty);
    await cubit.close();
  });

  test('an expired session (refresh rejected by the server) signs the customer out', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    events.sessionExpired();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.isSignedIn, isFalse);
    expect(wiper.logoutWipes, 1);
    await cubit.close();
  });

  test('a suspended provider signs the customer out and leaves a provider-unavailable notice', () async {
    final cubit = build();
    await cubit.signedIn(_user, fresh: true);
    events.providerSuspended();
    for (var i = 0; i < 5; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.providerUnavailable, isTrue);
    expect(wiper.logoutWipes, 1);
    await cubit.close();
  });
}
