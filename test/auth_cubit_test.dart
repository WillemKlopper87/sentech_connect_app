import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

class _RecordingWiper implements PersonalDataWiper {
  int logoutWipes = 0;
  int fullWipes = 0;

  @override
  Future<void> wipeOnLogout() async => logoutWipes++;

  @override
  Future<void> wipeEverything() async => fullWipes++;
}

void main() {
  late InMemorySecureStore secureStore;
  late SecureSessionStore sessionStore;
  late MockBiometricAuthenticator biometrics;
  late _RecordingWiper wiper;
  late AuthCubit cubit;

  setUp(() {
    secureStore = InMemorySecureStore();
    sessionStore = SecureSessionStore(secureStore);
    biometrics = MockBiometricAuthenticator();
    wiper = _RecordingWiper();
    cubit = AuthCubit(
      MockAuthRepository(),
      sessionStore: sessionStore,
      biometrics: biometrics,
      wiper: wiper,
    );
  });

  tearDown(() => cubit.close());

  test('biometrics are not offered before any session was established', () async {
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
  });

  test('biometric login is refused when no credential exists, without prompting', () async {
    await cubit.logInWithBiometrics(reason: 'test');
    expect(cubit.state.status, AuthStatus.failure);
    expect(biometrics.authenticateCalls, 0);
    expect(cubit.state.user, isNull);
  });

  test('password login persists the session securely and enables biometrics', () async {
    await cubit.logIn(mobileNumber: '0810000000', password: 'pw');
    expect(cubit.state.isSignedIn, isTrue);
    expect(await sessionStore.loadUser(), cubit.state.user);
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isTrue);
  });

  test('biometrics are hidden when nothing is enrolled on the device', () async {
    await cubit.logIn(mobileNumber: '0810000000', password: 'pw');
    biometrics.nextAvailability = BiometricAvailability.notEnrolled;
    await cubit.refreshBiometrics();
    expect(cubit.state.biometricsReady, isFalse);
  });

  test('successful biometric prompt signs the user back in after logout', () async {
    await cubit.logIn(mobileNumber: '0810000000', password: 'pw');
    await cubit.logOut();
    expect(cubit.state.isSignedIn, isFalse);
    expect(cubit.state.biometricsReady, isTrue); // credential survives logout
    expect(await sessionStore.loadUser(), isNull); // but the session does not

    await cubit.logInWithBiometrics(reason: 'test');
    expect(biometrics.authenticateCalls, 1);
    expect(cubit.state.isSignedIn, isTrue);
  });

  for (final (result, issue) in [
    (BiometricResult.cancelled, BiometricIssue.cancelled),
    (BiometricResult.notEnrolled, BiometricIssue.notEnrolled),
    (BiometricResult.unavailable, BiometricIssue.unavailable),
    (BiometricResult.lockedOut, BiometricIssue.lockedOut),
    (BiometricResult.permanentlyLockedOut, BiometricIssue.permanentlyLockedOut),
    (BiometricResult.failed, BiometricIssue.failed),
  ]) {
    test('biometric $result leaves the user signed out with $issue', () async {
      await cubit.logIn(mobileNumber: '0810000000', password: 'pw');
      await cubit.logOut();
      biometrics.nextResult = result;
      await cubit.logInWithBiometrics(reason: 'test');
      expect(cubit.state.isSignedIn, isFalse);
      expect(cubit.state.status, AuthStatus.failure);
      expect(cubit.state.biometricIssue, issue);
    });
  }

  test('logout wipes personal data; full wipe also drops the biometric credential', () async {
    await cubit.logIn(mobileNumber: '0810000000', password: 'pw');
    await cubit.logOut();
    expect(wiper.logoutWipes, 1);
    expect(await sessionStore.loadBiometricCredential(), isNotNull);

    await cubit.signOutAndWipeEverything();
    expect(wiper.fullWipes, 1);
    expect(await sessionStore.loadBiometricCredential(), isNull);
    expect(secureStore.snapshot, isEmpty);
    expect(cubit.state.biometricsReady, isFalse);
  });
}
