import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _emptyPage = {'items': <Object>[], 'next_cursor': null};

void main() {
  late ApiHarness h;
  late int expiredEvents;

  setUp(() {
    h = ApiHarness();
    expiredEvents = 0;
    h.events.expired.listen((_) => expiredEvents++);
  });

  Object? id(Object? d) => d;

  Failure? failureOf(Either<Failure, Object?> result) => result.match((f) => f, (_) => null);

  group('API origin and redirects (bearer token never leaves the API origin)', () {
    final offOrigin = {
      'another host': 'https://evil.test/v1/orders',
      'an http downgrade of the same host': 'http://api.test/v1/orders',
      'another port on the same host': 'https://api.test:8443/v1/orders',
    };

    for (final MapEntry(key: name, value: url) in offOrigin.entries) {
      test('an absolute URL to $name is refused and nothing is sent', () async {
        await h.signIn();
        h.adapter.on('GET', '/v1/orders', (_) => const FakeReply(200, _emptyPage));
        final result = await h.api.get(url, decode: id);
        expect(failureOf(result), isA<ServerFailure>());
        expect(h.adapter.requests, isEmpty, reason: 'no request, so no Authorization header, left the app');
      });

      test('an unauthenticated absolute URL to $name is refused too', () async {
        h.adapter.on('GET', '/v1/orders', (_) => const FakeReply(200, _emptyPage));
        final result = await h.api.get(url, authenticated: false, decode: id);
        expect(failureOf(result), isA<ServerFailure>());
        expect(h.adapter.requests, isEmpty);
      });
    }

    test('an absolute URL on the configured origin still works (control)', () async {
      await h.signIn();
      h.adapter.on('GET', '/v1/orders', (_) => const FakeReply(200, _emptyPage));
      final result = await h.api.get('https://api.test/v1/orders', decode: id);
      expect(result.isRight(), isTrue);
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('redirects are not followed: a 3xx is a failure and is requested exactly once', () async {
      await h.signIn();
      h.adapter.on(
        'GET',
        '/v1/orders',
        (_) => const FakeReply(302, null, {
          'location': ['https://evil.test/v1/orders'],
        }),
      );
      final result = await h.api.get('/v1/orders', decode: id);
      expect(failureOf(result), isA<ServerFailure>());
      expect(h.adapter.requests, hasLength(1));
      expect(h.adapter.requests.single.followRedirects, isFalse);
    });

    test('a redirect from the refresh endpoint keeps the session (and is not followed)', () async {
      await h.signIn();
      h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) => const FakeReply(307, null, {
            'location': ['https://evil.test/refresh'],
          }));
      final result = await h.api.get('/v1/orders', decode: id);
      expect(failureOf(result), isNot(isA<UnauthorizedFailure>()));
      expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh').single.followRedirects, isFalse);
      expect(await h.tokens.read(), isNotNull);
      await Future<void>.delayed(Duration.zero);
      expect(expiredEvents, 0);
    });
  });

  group('refresh rejection rules', () {
    Future<Failure?> run(FakeReply refreshReply) async {
      await h.signIn();
      h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) => refreshReply);
      final failure = failureOf(await h.api.get('/v1/orders', decode: id));
      await Future<void>.delayed(Duration.zero);
      return failure;
    }

    final rejected = {
      '401': FakeReply.problem(401, 'whatever'),
      '400 invalid_refresh_token': FakeReply.problem(400, 'invalid_refresh_token'),
      '403 refresh_token_reused': FakeReply.problem(403, 'refresh_token_reused'),
      '400 refresh_token_expired': FakeReply.problem(400, 'refresh_token_expired'),
    };
    for (final MapEntry(key: name, value: reply) in rejected.entries) {
      test('$name ends the session: tokens cleared, sessionExpired, Unauthorized', () async {
        final failure = await run(reply);
        expect(failure, isA<UnauthorizedFailure>());
        expect(await h.tokens.read(), isNull);
        expect(expiredEvents, 1);
      });
    }

    final unavailable = {
      '400 with another code': FakeReply.problem(400, 'validation_error'),
      '403 with another code': FakeReply.problem(403, 'forbidden'),
      '404': FakeReply.problem(404, 'not_found'),
      '422': FakeReply.problem(422, 'validation_error'),
      '500': FakeReply.problem(500, 'internal_error'),
      '503': FakeReply.problem(503, 'unavailable'),
      '408': FakeReply.problem(408, 'timeout'),
      '429': FakeReply.problem(429, 'rate_limited', headers: const {
        'retry-after': ['3'],
      }),
      'a WAF-style HTML 403': const FakeReply(403, '<html><body>Request blocked</body></html>', {
        'content-type': ['text/html'],
      }),
      'a 200 with a non-object body': const FakeReply(200, 'not a map'),
      'a 200 with a malformed token pair': const FakeReply(200, {'access_token': 1}),
    };
    for (final MapEntry(key: name, value: reply) in unavailable.entries) {
      test('$name keeps the session: tokens kept, no sign-out, a non-Unauthorized failure', () async {
        final failure = await run(reply);
        expect(failure, isNotNull);
        expect(failure, isNot(isA<UnauthorizedFailure>()));
        expect((await h.tokens.read())!.refreshToken, 'refresh-token-0000000-1');
        expect(expiredEvents, 0);
        expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(1), reason: 'not retried without a fresh token');
      });
    }
  });

  group('logout / sign-in during an in-flight refresh', () {
    Future<Future<Failure?>> startFlight(Completer<void> gate) async {
      await h.signIn();
      h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) async {
        await gate.future;
        return FakeReply(200, tokenPair());
      });
      final call = h.api.get('/v1/orders', decode: id).then(failureOf);
      for (var i = 0; i < 100 && h.adapter.requestsTo('POST', '/v1/auth/token/refresh').isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), hasLength(1));
      return call;
    }

    test('logout while refreshing: the refreshed tokens are discarded, the session stays cleared', () async {
      final gate = Completer<void>();
      final call = await startFlight(gate);
      await h.tokens.clear(); // logout
      gate.complete();

      expect(await call, isA<UnauthorizedFailure>());
      expect(await h.tokens.read(), isNull);
      expect(h.store.snapshot.containsKey(SecureTokenStore.key), isFalse);
      expect(h.adapter.requestsTo('GET', '/v1/orders'), hasLength(1), reason: 'no retry after logout');
      await Future<void>.delayed(Duration.zero);
      expect(expiredEvents, 0, reason: 'a deliberate logout is not an expiry');
    });

    test('a new sign-in while refreshing is not overwritten by the old session', () async {
      final gate = Completer<void>();
      final call = await startFlight(gate);
      await h.signIn(access: 'new-access', refresh: 'new-refresh');
      gate.complete();

      expect(await call, isA<UnauthorizedFailure>());
      expect((await h.tokens.read())!.accessToken, 'new-access');
    });

    test('a rejected refresh for an old session does not wipe a newer sign-in', () async {
      final gate = Completer<void>();
      await h.signIn();
      h.adapter.on('GET', '/v1/orders', (_) => FakeReply.problem(401, 'invalid_token'));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) async {
        await gate.future;
        return FakeReply.problem(401, 'invalid_refresh_token');
      });
      final call = h.api.get('/v1/orders', decode: id);
      for (var i = 0; i < 100 && h.adapter.requestsTo('POST', '/v1/auth/token/refresh').isEmpty; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      await h.signIn(access: 'new-access', refresh: 'new-refresh');
      gate.complete();
      await call;
      expect((await h.tokens.read())!.accessToken, 'new-access');
      expect(expiredEvents, 0);
    });
  });

  test('a 401 whose token was already replaced retries with the new token without a second refresh', () async {
    await h.signIn();
    final sentWith = <Object?>[]; // RequestOptions is reused by the retry, so record the header as sent
    h.adapter.on('GET', '/v1/orders', (r) async {
      sentWith.add(r.headers['Authorization']);
      if (r.headers['Authorization'] == 'Bearer access-1') {
        // Another caller refreshed while this request was in flight.
        await h.tokens.write(AuthTokens(
          accessToken: 'access-2',
          refreshToken: 'refresh-token-0000000-2',
          accessExpiresAt: h.now.add(const Duration(minutes: 15)),
          customerId: ApiHarness.customerId,
          tenantSlug: 'sentech',
        ));
        return FakeReply.problem(401, 'invalid_token');
      }
      return r.headers['Authorization'] == 'Bearer access-2' ? const FakeReply(200, _emptyPage) : FakeReply.problem(401, 'invalid_token');
    });
    final result = await h.api.get('/v1/orders', decode: id);
    expect(result.isRight(), isTrue);
    expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), isEmpty);
    expect(sentWith, ['Bearer access-1', 'Bearer access-2']);
  });

  test('PiiScrubber is the safety net: a phone number or token that reaches a log line is redacted', () async {
    h.adapter.on('GET', '/v1/customers/+27821234567', (_) => const FakeReply(200, {}));
    h.adapter.on('GET', '/v1/customers/0821234567', (_) => const FakeReply(200, {}));
    h.adapter.on('GET', '/v1/x/abcdefghijklmnopqrstuvwxyz0123456789', (_) => const FakeReply(200, {}));
    await h.api.get('/v1/customers/+27821234567', authenticated: false, decode: id);
    await h.api.get('/v1/customers/0821234567', authenticated: false, decode: id);
    await h.api.get('/v1/x/abcdefghijklmnopqrstuvwxyz0123456789', authenticated: false, decode: id);

    final log = h.logLines.join('\n');
    expect(h.logLines, hasLength(3));
    for (final secret in ['821234567', 'abcdefghijklmnopqrstuvwxyz0123456789']) {
      expect(log, isNot(contains(secret)), reason: secret);
    }
    expect(log, contains('[phone]'));
    expect(log, contains('[token]'));
  });
}
