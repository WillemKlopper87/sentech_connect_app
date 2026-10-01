import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/session_restore.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/install_marker.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

import 'helpers/api_harness.dart';

const _user = User(id: ApiHarness.customerId, fullName: 'Thandi Mokoena', mobileNumber: '+27821234567');

class _Wiper implements PersonalDataWiper {
  int wipes = 0;

  @override
  Future<void> wipeOnLogout() async => wipes++;

  @override
  Future<void> wipeEverything() async => wipes++;
}

class _ThrowingBiometrics extends MockBiometricAuthenticator {
  @override
  Future<BiometricAvailability> availability() async => throw StateError('plugin crashed');
}

void main() {
  late ApiHarness h;
  late SecureSessionStore sessions;
  late HttpAuthRepository auth;
  late _Wiper wiper;
  late InMemoryInstallMarker marker;

  setUp(() {
    h = ApiHarness();
    sessions = SecureSessionStore(h.store);
    auth = HttpAuthRepository(h.api, tokens: h.tokens, tenant: h.tenantContext, now: () => h.now);
    wiper = _Wiper();
    marker = InMemoryInstallMarker(present: true);
  });

  Future<AuthState> restore({BiometricAuthenticator? biometrics}) => restoreAuthState(
        sessionStore: sessions,
        auth: auth,
        biometrics: biometrics ?? MockBiometricAuthenticator(nextAvailability: BiometricAvailability.notEnrolled),
        wiper: wiper,
        secureStore: h.store,
        installMarker: marker,
      );

  Future<void> storeSession({String tenant = 'sentech', bool withTokens = true, String? tokenCustomer}) async {
    await sessions.saveUser(_user, tenantSlug: tenant);
    await sessions.saveBiometricCredential(_user.id);
    if (withTokens) {
      await h.tokens.write(AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-token-0000000-1',
        accessExpiresAt: h.now.add(const Duration(minutes: 10)),
        customerId: tokenCustomer ?? _user.id,
        tenantSlug: tenant,
      ));
    }
  }

  test('a consistent session is restored (opens straight away without usable biometrics)', () async {
    await storeSession();
    final state = await restore();
    expect(state.isSignedIn, isTrue);
    expect(state.user, _user);
    expect(wiper.wipes, 0);
  });

  test('a consistent session with enrolled biometrics starts locked', () async {
    await storeSession();
    final state = await restore(biometrics: MockBiometricAuthenticator());
    expect(state.status, AuthStatus.locked);
  });

  test('API tokens without a stored customer record are orphans and are discarded (N3)', () async {
    await h.tokens.write(AuthTokens(
      accessToken: 'access-1',
      refreshToken: 'refresh-token-0000000-1',
      accessExpiresAt: h.now.add(const Duration(minutes: 10)),
      customerId: _user.id,
      tenantSlug: 'sentech',
    ));
    final state = await restore();
    expect(state.isSignedIn, isFalse);
    expect(await h.tokens.read(), isNull);
  });

  test('first launch of a clean install writes the marker and starts signed out', () async {
    marker.present = false;
    expect((await restore()).status, AuthStatus.initial);
    expect(marker.present, isTrue);
    expect(wiper.wipes, 0, reason: 'nothing was held, nothing to wipe');
  });

  group('keychain that outlived an uninstall (no install marker)', () {
    test('a session of ANOTHER tenant is not resumed and storage is emptied', () async {
      await storeSession(tenant: 'acme-wifi');
      marker.present = false;
      final state = await restore();
      expect(state.isSignedIn, isFalse);
      expect(state.user, isNull);
      expect(h.store.snapshot, isEmpty);
      expect(await h.tokens.read(), isNull);
      expect(marker.present, isTrue);
      expect(wiper.wipes, 1);
    });

    test('a live session of the SAME tenant is not resumed either (no sign-in, no session)', () async {
      await storeSession();
      marker.present = false;
      final state = await restore(biometrics: MockBiometricAuthenticator());
      expect(state.isSignedIn, isFalse);
      expect(state.status, AuthStatus.initial);
      expect(h.store.snapshot, isEmpty);
      expect(await h.tokens.read(), isNull);
      expect(marker.present, isTrue);
    });

    test('the second launch (marker now present) keeps a session signed in since', () async {
      marker.present = false;
      await restore();
      await storeSession();
      expect((await restore()).isSignedIn, isTrue);
    });
  });

  test('a mock-phase user record with no tokens and no binding is discarded', () async {
    await h.store.write('session_user', '{"id":"${_user.id}","fullName":"x","mobileNumber":"y"}');
    await h.store.write('session_biometric_credential', _user.id);
    final state = await restore(biometrics: MockBiometricAuthenticator());
    expect(state.isSignedIn, isFalse);
    expect(state.status, AuthStatus.initial);
    expect(await sessions.loadUser(), isNull);
    expect(await sessions.loadBiometricCredential(), isNull);
    expect(wiper.wipes, 1);
  });

  test('a bound user record whose tokens are missing is a zombie and is discarded', () async {
    await storeSession(withTokens: false);
    final state = await restore();
    expect(state.isSignedIn, isFalse);
    expect(await sessions.loadUser(), isNull);
    expect(wiper.wipes, 1);
  });

  test('tokens that belong to a different customer than the stored user are discarded', () async {
    await storeSession(tokenCustomer: 'someone-else');
    final state = await restore();
    expect(state.isSignedIn, isFalse);
    expect(await h.tokens.read(), isNull);
    expect(await sessions.loadUser(), isNull);
  });

  test('tokens for another tenant than the record is bound to are discarded', () async {
    await storeSession();
    await h.tokens.write(AuthTokens(
      accessToken: 'a',
      refreshToken: 'r',
      accessExpiresAt: h.now.add(const Duration(minutes: 10)),
      customerId: _user.id,
      tenantSlug: 'acme-wifi',
    ));
    expect((await restore()).isSignedIn, isFalse);
    expect(await h.tokens.read(), isNull);
  });

  test('a biometric plugin that throws is treated as unavailable (documented: the session opens unlocked)', () async {
    await storeSession();
    expect((await restore(biometrics: _ThrowingBiometrics())).isSignedIn, isTrue);
  });

  test('any storage failure while restoring starts signed out instead of crashing the app', () async {
    await storeSession();
    final broken = SecureSessionStore(_BrokenStore());
    final state = await restoreAuthState(
      sessionStore: broken,
      auth: auth,
      biometrics: MockBiometricAuthenticator(),
      wiper: wiper,
      secureStore: h.store,
      installMarker: marker,
    );
    expect(state.status, AuthStatus.initial);
  });
}

/// A Keystore/Keychain that fails every call.
class _BrokenStore implements SecureStore {
  @override
  Future<String?> read(String key) async => throw StateError('keystore unavailable');

  @override
  Future<void> write(String key, String value) async => throw StateError('keystore unavailable');

  @override
  Future<void> delete(String key) async => throw StateError('keystore unavailable');

  @override
  Future<void> deleteAll() async => throw StateError('keystore unavailable');
}
