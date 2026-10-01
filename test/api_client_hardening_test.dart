import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/network/session_events.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

/// A token store whose storage can be made to fail (Keystore errors happen).
class _FlakyTokenStore implements TokenStore {
  _FlakyTokenStore(this._inner);

  final TokenStore _inner;
  bool failReads = false;
  bool failWrites = false;
  bool failClears = false;

  @override
  int get generation => _inner.generation;

  @override
  int get sessionGeneration => _inner.sessionGeneration;

  @override
  Future<AuthTokens?> read() async {
    if (failReads) throw StateError('keystore unavailable');
    return _inner.read();
  }

  @override
  Future<void> write(AuthTokens tokens) async {
    if (failWrites) throw StateError('keystore unavailable');
    return _inner.write(tokens);
  }

  @override
  Future<void> clear() async {
    if (failClears) {
      await _inner
          .clear(); // the in-memory state is gone even if the disk delete fails
      throw StateError('keystore unavailable');
    }
    return _inner.clear();
  }
}

void main() {
  Object? id(Object? d) => d;

  test(
    'a duplicated X-Request-ID response header does not break the call or its log line',
    () async {
      final h = ApiHarness();
      h.adapter.on(
        'GET',
        '/v1/tenants',
        (_) => const FakeReply(
          200,
          {'tenants': <Object>[]},
          {
            'x-request-id': ['one', 'two'],
          },
        ),
      );
      final result = await h.api.get(
        '/v1/tenants',
        authenticated: false,
        decode: id,
      );
      expect(result.isRight(), isTrue);
      expect(h.logLines, hasLength(1));
      expect(h.logLines.single, contains('rid=one'));
    },
  );

  group('storage failures complete the request instead of hanging it', () {
    late ApiHarness h;
    late _FlakyTokenStore flaky;
    late ApiClient api;
    var expiredEvents = 0;

    setUp(() async {
      h = ApiHarness();
      await h.signIn();
      flaky = _FlakyTokenStore(h.tokens);
      final events = SessionEvents();
      expiredEvents = 0;
      events.expired.listen((_) => expiredEvents++);
      api = ApiClient(
        baseUrl: Uri.parse('https://api.test'),
        tokens: flaky,
        tenant: TenantContext(),
        sessionEvents: events,
        adapter: h.adapter,
        log: h.logLines.add,
        now: () => h.now,
      );
    });

    test(
      'an unreadable session signs the customer out (not "offline" forever) and is not sticky',
      () async {
        flaky.failReads = true;
        final result = await api
            .get('/v1/orders', decode: id)
            .timeout(const Duration(seconds: 5));
        expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
        expect(h.adapter.requests, isEmpty);
        await Future<void>.delayed(Duration.zero);
        expect(expiredEvents, 1);

        // The failed-read state is not sticky: once storage works again the
        // client simply has no session (cleared) instead of failing forever.
        flaky.failReads = false;
        expect(await flaky.read(), isNull);
        final again = await api
            .get('/v1/orders', decode: id)
            .timeout(const Duration(seconds: 5));
        expect(again.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
        expect(h.adapter.requests, isEmpty);
      },
    );

    test(
      'a token-read failure does not break a scoped public call (catalogue) but ends a scoped signed-in call cleanly',
      () async {
        flaky.failReads = true;
        h.adapter.on(
          'GET',
          '/v1/products',
          (_) => const FakeReply(200, {'items': <Object>[]}),
        );
        final scope = await api.captureScope(); // must not throw
        final publicResult = await api
            .get('/v1/products', authenticated: false, scope: scope, decode: id)
            .timeout(const Duration(seconds: 5));
        expect(publicResult.isRight(), isTrue);
        expect(expiredEvents, 0);

        final scopedAuthed = await api
            .get('/v1/orders', scope: await api.captureScope(), decode: id)
            .timeout(const Duration(seconds: 5));
        expect(
          scopedAuthed.match((f) => f, (_) => null),
          isA<UnauthorizedFailure>(),
        );
        await Future<void>.delayed(Duration.zero);
        expect(expiredEvents, 1); // normal expireSession path, no zombie
        expect(h.adapter.requestsTo('GET', '/v1/orders'), isEmpty);
      },
    );

    test('a failing token clear still announces the expired session', () async {
      flaky.failClears = true;
      h.adapter.on(
        'GET',
        '/v1/orders',
        (_) => FakeReply.problem(401, 'invalid_token'),
      );
      h.adapter.on(
        'POST',
        '/v1/auth/token/refresh',
        (_) => FakeReply.problem(401, 'invalid_refresh_token'),
      );
      final result = await api
          .get('/v1/orders', decode: id)
          .timeout(const Duration(seconds: 5));
      expect(result.match((f) => f, (_) => null), isA<UnauthorizedFailure>());
      await Future<void>.delayed(Duration.zero);
      expect(expiredEvents, 1);
    });

    test(
      'a refresh whose new tokens cannot be stored is a failure, not a hang, and not a logout',
      () async {
        flaky.failWrites = true;
        h.adapter.on(
          'GET',
          '/v1/orders',
          (_) => FakeReply.problem(401, 'invalid_token'),
        );
        h.adapter.on(
          'POST',
          '/v1/auth/token/refresh',
          (_) => FakeReply(200, tokenPair()),
        );
        final result = await api
            .get('/v1/orders', decode: id)
            .timeout(const Duration(seconds: 5));
        expect(result.match((f) => f, (_) => null), isA<NetworkFailure>());
        await Future<void>.delayed(Duration.zero);
        expect(expiredEvents, 0);
      },
    );
  });
}
