import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/hotspot_login/data/http_hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/data/mock_hotspot_login_repository.dart';
import 'package:sentech_connect_app/features/hotspot_login/domain/entities/login_token.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

void main() {
  late ApiHarness h;
  late HttpHotspotLoginRepository repo;
  const path = '/v1/me/hotspot/login-token';

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpHotspotLoginRepository(h.api);
  });

  test('posts an empty body (no mac, nas_id, login_url or dst) and no Idempotency-Key', () async {
    h.adapter.on('POST', path, (_) => FakeReply(201, fixture('login_token.json')));
    final token = (await repo.createLoginToken()).getOrElse((f) => throw StateError(f.message));
    final request = h.adapter.requestsTo('POST', path).single;
    final body = request.data is String ? jsonDecode(request.data as String) : request.data;
    expect(body, isA<Map<Object?, Object?>>());
    expect((body as Map).containsKey('mac'), isFalse);
    expect(body, isEmpty);
    expect(request.headers.keys.map((k) => k.toLowerCase()), isNot(contains('idempotency-key')));
    expect(request.headers['Authorization'], 'Bearer access-1');
    expect(token.username, 'c.9f3a1b2c4d5e');
    expect(token.password, 'Zk7-demo-only-Qx2');
    expect(token.expiresAt, DateTime.utc(2026, 10, 30, 12, 5));
  });

  test('works without the optional hand-off', () async {
    h.adapter.on(
      'POST',
      path,
      (_) => const FakeReply(201, {'username': 'c.a1', 'password': 'pw', 'expires_at': '2026-10-30T12:05:00+00:00'}),
    );
    expect((await repo.createLoginToken()).isRight(), isTrue);
  });

  test('the password never reaches the request log or the failure text', () async {
    h.adapter.on('POST', path, (_) => FakeReply(201, fixture('login_token.json')));
    await repo.createLoginToken();
    expect(h.logLines.join('\n'), isNot(contains('Zk7-demo-only-Qx2')));
    expect(LoginToken(username: 'u', password: 'secret-pw', expiresAt: DateTime.utc(2026)).toString(), isNot(contains('secret-pw')));
  });

  group('failures', () {
    Future<Failure?> failWith(FakeReply reply) async {
      h.adapter.on('POST', path, (_) => reply);
      return _failure(await repo.createLoginToken());
    }

    test('409 no_active_entitlement', () async {
      expect(await failWith(FakeReply.problem(409, 'no_active_entitlement')), isA<NoActiveEntitlementFailure>());
    });

    test('409 feature_disabled', () async {
      expect(await failWith(FakeReply.problem(409, 'feature_disabled')), isA<FeatureDisabledFailure>());
    });

    test('422 controller_not_supported', () async {
      expect(await failWith(FakeReply.problem(422, 'controller_not_supported')), isA<ControllerNotSupportedFailure>());
    });

    test('429 rate_limited keeps Retry-After', () async {
      final failure = await failWith(
        FakeReply.problem(429, 'rate_limited', headers: {'retry-after': ['600']}),
      );
      expect(failure, isA<RateLimitedFailure>());
      expect((failure! as RateLimitedFailure).retryAfter, const Duration(seconds: 600));
    });

    test('offline', () async {
      expect(await failWith(const FakeReply.error(DioExceptionType.connectionError)), isA<NetworkFailure>());
    });
  });

  test('the demo mock issues a new login each time, valid for five minutes', () async {
    final now = DateTime.utc(2026, 10, 30, 12);
    final mock = MockHotspotLoginRepository(now: () => now);
    final a = (await mock.createLoginToken()).getOrElse((f) => throw StateError(f.message));
    final b = (await mock.createLoginToken()).getOrElse((f) => throw StateError(f.message));
    expect(a.username, isNot(b.username));
    expect(a.expiresAt, now.add(const Duration(minutes: 5)));
  });
}
