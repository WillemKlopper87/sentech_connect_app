import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/secure_session_store.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';
import 'package:sentech_connect_app/features/tenant/data/repositories/mock_tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';

const _user = User(id: ApiHarness.customerId, fullName: 'Thandi Mokoena', mobileNumber: '+27821234567');

class _Wiper implements PersonalDataWiper {
  int wipes = 0;

  @override
  Future<void> wipeOnLogout() async => wipes++;

  @override
  Future<void> wipeEverything() async => wipes++;
}

/// The real chain used by the app: HttpAuthRepository + AuthCubit +
/// TenantCubit(onTenantApplied: ensureSessionMatches) over one secure store.
void main() {
  late ApiHarness h;
  late SecureSessionStore sessions;
  late _Wiper wiper;
  late AuthCubit auth;
  late InMemoryTenantPreferences prefs;
  final tenantStatesWhenSessionEnded = <TenantStatus>[];

  setUp(() {
    // The active tenant starts as 'acme-wifi' so the first activation of
    // 'sentech' (the only tenant the mock directory offers) is a real change.
    h = ApiHarness(tenant: 'acme-wifi');
    sessions = SecureSessionStore(h.store);
    wiper = _Wiper();
    prefs = InMemoryTenantPreferences();
    tenantStatesWhenSessionEnded.clear();
  });

  tearDown(() => auth.close());

  Future<void> storeSession({required String tenant, String? tokenCustomer, bool withTokens = true}) async {
    await sessions.saveUser(_user, tenantSlug: tenant);
    await sessions.saveBiometricCredential(_user.id);
    if (withTokens) {
      await h.tokens.write(AuthTokens(
        accessToken: 'access-1',
        refreshToken: 'refresh-1',
        accessExpiresAt: h.now.add(const Duration(minutes: 10)),
        customerId: tokenCustomer ?? _user.id,
        tenantSlug: tenant,
      ));
    }
  }

  TenantCubit buildApp({AuthState? initial}) {
    final repo = HttpAuthRepository(h.api, tokens: h.tokens, tenant: h.tenantContext, now: () => h.now);
    auth = AuthCubit(
      repo,
      sessionStore: sessions,
      biometrics: MockBiometricAuthenticator(),
      wiper: wiper,
      initial: initial ?? const AuthState(status: AuthStatus.success, user: _user),
      sessionExpired: h.events.expired,
      activeTenantSlug: () => h.tenantContext.slug,
    );
    late final TenantCubit tenants;
    tenants = TenantCubit(
      repository: MockTenantRepository(),
      context: h.tenantContext,
      preferences: prefs,
      onTenantChanging: () => auth.logOut(),
      onTenantApplied: (slug) async {
        await auth.ensureSessionMatches(slug);
        if (!auth.state.isSignedIn) tenantStatesWhenSessionEnded.add(tenants.state.status);
      },
    );
    addTearDown(tenants.close);
    return tenants;
  }

  test('FIRST activation (reinstall / no saved tenant) of another tenant ends the leftover session before the app shows', () async {
    await storeSession(tenant: 'acme-wifi'); // the Keychain kept tenant A's session; prefs are gone
    final tenants = buildApp();
    await tenants.bootstrap();

    expect(tenants.state.status, TenantStatus.ready);
    expect(h.tenantContext.slug, 'sentech');
    expect(auth.state.isSignedIn, isFalse);
    expect(auth.state.user, isNull, reason: "tenant A's customer must never be shown under tenant B");
    expect(await h.tokens.read(), isNull);
    expect(await sessions.loadUser(), isNull);
    expect(wiper.wipes, 1);
    // The sign-out happened BEFORE the tenant was announced as ready.
    expect(tenantStatesWhenSessionEnded, [TenantStatus.loading]);
    expect(h.adapter.requests, isEmpty, reason: "tenant A's token is never sent to tenant B's API");
  });

  test('first activation of the SAME tenant with a matching session keeps the customer signed in', () async {
    h.tenantContext.slug = 'sentech';
    await storeSession(tenant: 'sentech');
    final tenants = buildApp();
    await tenants.bootstrap();
    expect(tenants.state.status, TenantStatus.ready);
    expect(auth.state.isSignedIn, isTrue);
    expect(await h.tokens.read(), isNotNull);
    expect(wiper.wipes, 0);
  });

  test('a user record with no tokens (mock-phase upgrade) is signed out on first activation', () async {
    h.tenantContext.slug = 'sentech';
    await h.store.write('session_user', '{"id":"${_user.id}","fullName":"x","mobileNumber":"y"}');
    final tenants = buildApp();
    await tenants.bootstrap();
    expect(auth.state.isSignedIn, isFalse);
    expect(await sessions.loadUser(), isNull);
  });

  test('tokens of another customer than the stored user are signed out on first activation', () async {
    h.tenantContext.slug = 'sentech';
    await storeSession(tenant: 'sentech', tokenCustomer: 'someone-else');
    final tenants = buildApp();
    await tenants.bootstrap();
    expect(auth.state.isSignedIn, isFalse);
    expect(await h.tokens.read(), isNull);
  });

  test('a locked session (cold start with biometrics) of another tenant is ended too', () async {
    await storeSession(tenant: 'acme-wifi');
    final tenants = buildApp(initial: AuthState.restore(user: _user, hasBiometricCredential: true, biometricsAvailable: true));
    expect(auth.state.status, AuthStatus.locked);
    await tenants.bootstrap();
    expect(auth.state.status, AuthStatus.initial);
    expect(auth.state.user, isNull);
  });

  test('an authenticated call with wrong-tenant tokens signs the app out (no zombie session)', () async {
    await storeSession(tenant: 'acme-wifi');
    buildApp();
    // The tenant context moved on without a sign-out (a path nobody anticipated).
    h.tenantContext.slug = 'sentech';
    h.adapter.on('GET', '/v1/orders', (_) => const FakeReply(200, {'items': <Object>[]}));
    await h.api.get<Object?>('/v1/orders', decode: (d) => d);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(auth.state.isSignedIn, isFalse);
    expect(wiper.wipes, 1);
    expect(h.adapter.requests, isEmpty);
  });

  test('a failing sign-out during activation keeps the app out of ready (retryable failure)', () async {
    await storeSession(tenant: 'acme-wifi');
    final tenants = TenantCubit(
      repository: MockTenantRepository(),
      context: h.tenantContext,
      preferences: prefs,
      onTenantApplied: (_) async => throw StateError('storage'),
    );
    addTearDown(tenants.close);
    auth = AuthCubit(
      HttpAuthRepository(h.api, tokens: h.tokens, tenant: h.tenantContext),
      sessionStore: sessions,
      biometrics: MockBiometricAuthenticator(),
      wiper: wiper,
    );
    await tenants.bootstrap();
    expect(tenants.state.status, TenantStatus.failure);
  });

  test('the leftover session of another tenant is wiped locally without any network call', () async {
    await storeSession(tenant: 'acme-wifi');
    h.tenantContext.slug = 'acme-wifi';
    h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply.error(DioExceptionType.connectionError));
    final tenants = buildApp();
    await tenants.bootstrap();
    expect(tenants.state.status, TenantStatus.ready);
    expect(auth.state.isSignedIn, isFalse);
    expect(await h.tokens.read(), isNull);
  });
}
