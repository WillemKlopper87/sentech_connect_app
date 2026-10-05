import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/app/default_personal_data_wiper.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/http_passes_repository.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/pass_local_store.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('offline load returns cached passes with original loadedAt', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    var offline = false;
    h.adapter.on(
      'GET',
      '/v1/me/entitlements',
      (_) => offline
          ? const FakeReply.error(DioExceptionType.connectionError)
          : FakeReply(200, fixture('entitlements_page.json')),
    );
    final repo = HttpPassesRepository(
      h.api,
      tokens: h.tokens,
      cache: store,
      now: () => h.now,
    );
    final first = (await repo.getPassLoad()).getOrElse(
      (f) => throw StateError(f.message),
    );
    expect(first.fromCache, false);
    h.now = h.now.add(const Duration(minutes: 10));
    offline = true;
    final second = (await repo.getPassLoad()).getOrElse(
      (f) => throw StateError(f.message),
    );
    expect(second.fromCache, true);
    expect(second.loadedAt, first.loadedAt);
    expect(second.passes, first.passes);
    final cubit = PassesCubit(repo);
    await cubit.load();
    expect(cubit.state.fromCache, true);
    expect(cubit.state.loadedAt, first.loadedAt);
    await cubit.close();
  });

  test('wiping personal data removes the passes cache', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    h.adapter.on(
      'GET',
      '/v1/me/entitlements',
      (_) => FakeReply(200, fixture('entitlements_page.json')),
    );
    final repo = HttpPassesRepository(
      h.api,
      tokens: h.tokens,
      cache: store,
      now: () => h.now,
    );
    expect((await repo.getPassLoad()).isRight(), true);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getKeys().any((k) => k.startsWith('passes_cache:')), true);
    final secure = InMemorySecureStore();
    final wiper = DefaultPersonalDataWiper(
      registration: LocalRegistrationRepository(secure),
      checkout: MockCheckoutRepository(secure),
      freeWifi: MockFreeWifiRepository(secure, clock: FakePlatformClock()),
      consent: LocalConsentRepository(secure),
      passes: store,
    );
    await wiper.wipeOnLogout();
    expect(prefs.getKeys().any((k) => k.startsWith('passes_cache:')), false);
  });

  test('current and all queries never reuse each other as cache', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    var offline = false;
    h.adapter.on(
      'GET',
      '/v1/me/entitlements',
      (_) => offline
          ? const FakeReply.error(DioExceptionType.connectionError)
          : FakeReply(200, fixture('entitlements_page.json')),
    );
    final repo = HttpPassesRepository(
      h.api,
      tokens: h.tokens,
      cache: store,
      now: () => h.now,
    );
    expect((await repo.getPassLoad()).isRight(), true);
    offline = true;
    expect((await repo.getPassLoad(includeExpired: true)).isLeft(), true);
    expect(
      (await repo.getPassLoad())
          .getOrElse((f) => throw StateError(f.message))
          .fromCache,
      true,
    );
  });

  test('a server failure never reads the last good cache', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    var fail = false;
    h.adapter.on(
      'GET',
      '/v1/me/entitlements',
      (_) => fail
          ? const FakeReply(500, {'title': 'Server error'})
          : FakeReply(200, fixture('entitlements_page.json')),
    );
    final repo = HttpPassesRepository(
      h.api,
      tokens: h.tokens,
      cache: store,
      now: () => h.now,
    );
    expect((await repo.getPassLoad()).isRight(), true);
    fail = true;
    expect((await repo.getPassLoad()).isLeft(), true);
  });

  test(
    'a response arriving after wipe is hidden and cannot refill cache',
    () async {
      final h = ApiHarness();
      await h.signIn();
      final store = PassLocalStore();
      final reply = Completer<FakeReply>();
      h.adapter.on('GET', '/v1/me/entitlements', (_) => reply.future);
      final repo = HttpPassesRepository(
        h.api,
        tokens: h.tokens,
        cache: store,
        now: () => h.now,
      );
      final pending = repo.getPassLoad();
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await store.clearPersonalData();
      reply.complete(FakeReply(200, fixture('entitlements_page.json')));
      expect(
        (await pending).match((f) => f, (_) => null),
        isA<UnauthorizedFailure>(),
      );
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getKeys().any((k) => k.startsWith('passes_cache:')), false);
    },
  );
  test('a different customer cannot read the prior customer cache', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    var offline = false;
    h.adapter.on(
      'GET',
      '/v1/me/entitlements',
      (_) => offline
          ? const FakeReply.error(DioExceptionType.connectionError)
          : FakeReply(200, fixture('entitlements_page.json')),
    );
    final repo = HttpPassesRepository(
      h.api,
      tokens: h.tokens,
      cache: store,
      now: () => h.now,
    );
    expect((await repo.getPassLoad()).isRight(), true);
    await h.tokens.write(
      AuthTokens(
        accessToken: 'other-access',
        refreshToken: 'other-refresh',
        accessExpiresAt: h.now.add(const Duration(minutes: 15)),
        customerId: 'customer-B',
        tenantSlug: 'sentech',
      ),
    );
    offline = true;
    expect((await repo.getPassLoad()).isLeft(), true);
  });
}
