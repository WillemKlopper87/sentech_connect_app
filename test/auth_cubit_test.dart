import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

const _user = User(id: 'c1', fullName: 'Lindiwe Khumalo', mobileNumber: '+27810000000');

class _RecordingWiper implements PersonalDataWiper {
  int logoutWipes = 0;
  int fullWipes = 0;

  @override
  Future<void> wipeOnLogout() async => logoutWipes++;

  @override
  Future<void> wipeEverything() async => fullWipes++;
}

class _FakeAuthRepository extends MockAuthRepository {
  _FakeAuthRepository() : super(latency: Duration.zero);

  int logOuts = 0;
  int resumes = 0;
  Object? logOutError;
  Either<Failure, User> resumeResult = const Right(_user);

  @override
  Future<Either<Failure, User>> resumeSession() async {
    resumes++;
    return resumeResult;
  }

  @override
  Future<void> logOut() async {
    logOuts++;
    final error = logOutError;
    if (error != null) throw error;
  }
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
      );

  Future<AuthCubit> lockedCubit() async {
    await sessionStore.saveUser(_user);
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
}
