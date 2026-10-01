import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _emptyPage = {'items': <Object>[], 'next_cursor': null};

void main() {
  late ApiHarness h;

  setUp(() => h = ApiHarness());

  Object? id(Object? d) => d;

  test('authenticated calls carry the bearer token and a request id', () async {
    await h.signIn();
    h.adapter.on('GET', '/v1/me/profile', (_) => const FakeReply(200, {'id': 'c1'}));
    final result = await h.api.get('/v1/me/profile', decode: id);
    expect(result.isRight(), isTrue);
    final sent = h.adapter.requests.single;
    expect(sent.headers['Authorization'], 'Bearer access-1');
    expect(sent.headers['X-Request-ID'], matches(RegExp(r'^app-[0-9a-f]{24}$')));
  });

  test('unauthenticated calls never carry Authorization, even when signed in', () async {
    await h.signIn();
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply(200, {'tenants': <Object>[]}));
    await h.api.get('/v1/tenants', authenticated: false, decode: id);
    expect(h.adapter.requests.single.headers.containsKey('Authorization'), isFalse);
  });

  test('concurrent 401s share ONE refresh and each request is retried once', () async {
    await h.signIn();
    final gate = Completer<void>();
    h.adapter.on('GET', '/v1/orders', (r) {
      return r.headers['Authorization'] == 'Bearer access-2' ? const FakeReply(200, _emptyPage) : FakeReply.problem(401, 'invalid_token');
    });
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) async {
      await gate.future;
      return FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2'));
    });

    final calls = [for (var i = 0; i < 3; i++) h.api.get('/v1/orders', decode: id)];
    for (var i = 0; i < 100 && h.adapter.requestsTo('GET', '/v1/orders').length < 3; i++) {
      await Future<void>.delayed(Duration.zero);
    }
    gate.complete();
    final results = await Future.wait(calls);

    expect(results.every((r) => r.isRight()), isTrue);
    final refreshes = h.adapter.requestsTo('POST', '/v1/auth/token/refresh');
    expect(refreshes, hasLength(1));
    expect(refreshes.single.data, {'tenant': 'sentech', 'refresh_token': 'refresh-1'});
    expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(6));
    expect((await h.tokens.read())!.refreshToken, 'refresh-2');
  });

  test('a request is retried at most once', () async {
    await h.signIn();
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(2));
    expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), hasLength(1));
  });

  test('a rejected refresh clears the tokens and announces the expired session', () async {
    await h.signIn();
    final expired = expectLater(h.events.expired, emits(null));
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply.problem(401, 'invalid_refresh_token'));
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(await h.tokens.read(), isNull);
    await expired;
  });

  test('a refresh that cannot reach the server keeps the session (offline is not a logout)', () async {
    await h.signIn();
    var expiredEvents = 0;
    final sub = h.events.expired.listen((_) => expiredEvents++);
    h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => const FakeReply.error(DioExceptionType.connectionError));
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<NetworkFailure>());
    expect(await h.tokens.read(), isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(expiredEvents, 0);
    await sub.cancel();
  });

  test('a token about to expire is refreshed before the call (no wasted 401)', () async {
    await h.signIn(validFor: const Duration(seconds: 10));
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/orders', (r) {
      return r.headers['Authorization'] == 'Bearer access-2' ? const FakeReply(200, _emptyPage) : FakeReply.problem(401, 'invalid_token');
    });
    expect((await h.api.get('/v1/orders', decode: id)).isRight(), isTrue);
    expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(1));
  });

  test("tokens issued for another tenant are never sent (tenant switch can't leak a session)", () async {
    await h.signIn(tenant: 'sentech');
    h.tenantContext.slug = 'acme-wifi';
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requests, isEmpty);
  });

  test('no stored session -> UnauthorizedFailure without touching the network', () async {
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requests, isEmpty);
  });

  test('the Idempotency-Key survives the 401 retry, so a replay cannot create a second order', () async {
    await h.signIn();
    var first = true;
    h.adapter.on('POST', '/v1/orders', (_) {
      if (first) {
        first = false;
        return FakeReply.problem(401, 'invalid_token');
      }
      return const FakeReply(201, {'id': 'o1'});
    });
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    final key = newIdempotencyKey();
    final result = await h.api.post('/v1/orders', body: {'lines': <Object>[]}, idempotencyKey: key, decode: id);
    expect(result.isRight(), isTrue);
    final sent = h.adapter.requestsTo('POST', '/v1/orders');
    expect(sent.map((r) => r.headers['Idempotency-Key']), [key, key]);
  });

  test('timeouts surface as NetworkFailure', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply.error(DioExceptionType.receiveTimeout));
    final result = await h.api.get('/v1/tenants', authenticated: false, decode: id);
    expect(result.match((f) => f, (_) => null), isA<NetworkFailure>());
  });

  test('a per-request timeout is applied to that request only', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply(200, {'tenants': <Object>[]}));
    await h.api.get('/v1/tenants', authenticated: false, timeout: const Duration(seconds: 3), decode: id);
    await h.api.get('/v1/tenants', authenticated: false, decode: id);
    expect(h.adapter.requests[0].receiveTimeout, const Duration(seconds: 3));
    expect(h.adapter.requests[1].receiveTimeout, const Duration(seconds: 20));
  });

  test('log lines never contain tokens, bodies, phone numbers or query strings', () async {
    await h.signIn(access: 'secret-access-token', refresh: 'secret-refresh-token');
    h.adapter.on('POST', '/v1/auth/otp/request', (_) => const FakeReply(202, {'challenge_id': 'c', 'expires_in_seconds': 300}));
    h.adapter.on('GET', '/v1/products', (_) => const FakeReply(200, _emptyPage));
    h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply.problem(422, 'x', detail: 'phone +27821234567 is bad'));
    await h.api.post('/v1/auth/otp/request', authenticated: false, body: {'tenant': 'sentech', 'phone': '+27821234567'}, decode: id);
    await h.api.get('/v1/products', authenticated: false, query: {'tenant': 'sentech', 'cursor': 'abc'}, decode: id);
    await h.api.get('/v1/me/profile', decode: id);

    final log = h.logLines.join('\n');
    expect(h.logLines, hasLength(3));
    expect(log, contains('POST /v1/auth/otp/request -> 202'));
    for (final secret in ['secret-access-token', 'secret-refresh-token', '+2782', '0821234567', 'tenant=', 'cursor', 'Bearer']) {
      expect(log, isNot(contains(secret)), reason: secret);
    }
  });

  test('a malformed success body is a ServerFailure, not a crash', () async {
    h.adapter.on('GET', '/v1/tenants', (_) => const FakeReply(200, 'not a map'));
    final result = await h.api.get<int>('/v1/tenants', authenticated: false, decode: (d) => (d! as Map)['x'] as int);
    expect(result.match((f) => f, (_) => null), isA<ServerFailure>());
  });

  test('idempotency keys and request ids match the server patterns and do not repeat', () {
    final keys = {for (var i = 0; i < 200; i++) newIdempotencyKey()};
    expect(keys, hasLength(200));
    expect(keys.every(RegExp(r'^[A-Za-z0-9_.:-]{8,128}$').hasMatch), isTrue);
    expect(newRequestId(), matches(RegExp(r'^[A-Za-z0-9._-]{1,64}$')));
  });
}
