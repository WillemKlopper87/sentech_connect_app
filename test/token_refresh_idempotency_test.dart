import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/network/token_refresher.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _path = '/v1/auth/token/refresh';
final _keyPattern = RegExp(r'^[A-Za-z0-9_.:-]{8,128}$');

void main() {
  late ApiHarness h;
  late int expiredEvents;

  setUp(() async {
    h = ApiHarness();
    expiredEvents = 0;
    h.events.expired.listen((_) => expiredEvents++);
    await h.signIn();
  });

  List<String?> keysSent() => [for (final r in h.adapter.requestsTo('POST', _path)) r.headers['Idempotency-Key'] as String?];

  test('every refresh carries a well-formed Idempotency-Key', () async {
    h.adapter.on('POST', _path, (_) => FakeReply(200, tokenPair()));
    expect(await h.api.refresher.refresh(), isA<RefreshSucceeded>());
    final keys = keysSent();
    expect(keys, hasLength(1));
    expect(keys.single, matches(_keyPattern));
  });

  test('a timeout is retried with the SAME key and the session survives', () async {
    var attempt = 0;
    h.adapter.on('POST', _path, (_) {
      attempt++;
      return attempt == 1 ? const FakeReply.error(DioExceptionType.receiveTimeout) : FakeReply(200, tokenPair());
    });
    expect(await h.api.refresher.refresh(), isA<RefreshSucceeded>());
    final keys = keysSent();
    expect(keys, hasLength(2));
    expect(keys[0], keys[1]);
    expect((await h.tokens.read())!.refreshToken, 'refresh-2');
    expect(expiredEvents, 0);
  });

  test('lost response: the server rotated but the reply never arrived; the keyed retry gets the same pair', () async {
    // A faithful stand-in for the platform: rotation + reuse detection + a
    // replay cache keyed on (refresh token, Idempotency-Key).
    final replay = <String, Map<String, Object?>>{};
    final spent = <String>{};
    var dropFirstReply = true;
    h.adapter.on('POST', _path, (r) {
      final token = (r.data as Map)['refresh_token'] as String;
      final key = r.headers['Idempotency-Key'] as String?;
      final cached = key == null ? null : replay['$token|$key'];
      final Map<String, Object?> pair;
      if (cached != null) {
        pair = cached;
      } else if (spent.contains(token)) {
        return FakeReply.problem(401, 'refresh_token_reused');
      } else {
        spent.add(token);
        pair = tokenPair();
        if (key != null) replay['$token|$key'] = pair;
      }
      if (dropFirstReply) {
        dropFirstReply = false;
        return const FakeReply.error(DioExceptionType.receiveTimeout);
      }
      return FakeReply(200, pair);
    });

    expect(await h.api.refresher.refresh(), isA<RefreshSucceeded>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(2));
    expect((await h.tokens.read())!.refreshToken, 'refresh-2');
    await Future<void>.delayed(Duration.zero);
    expect(expiredEvents, 0, reason: 'the session must not be revoked by our own retry');
  });

  test('without the key the same lost response would have ended the session (sanity of the scenario)', () async {
    final spent = <String>{};
    var dropFirstReply = true;
    h.adapter.on('POST', _path, (r) {
      final token = (r.data as Map)['refresh_token'] as String;
      final reuse = !spent.add(token);
      if (reuse) return FakeReply.problem(401, 'refresh_token_reused');
      if (dropFirstReply) {
        dropFirstReply = false;
        return const FakeReply.error(DioExceptionType.receiveTimeout);
      }
      return FakeReply(200, tokenPair());
    });
    expect(await h.api.refresher.refresh(), isA<RefreshRejected>());
    expect(await h.tokens.read(), isNull);
  });

  test('a new refresh operation (after the token rotated) uses a NEW key', () async {
    h.adapter.on('POST', _path, (_) => FakeReply(200, tokenPair()));
    await h.api.refresher.refresh();
    h.adapter.on('POST', _path, (_) => FakeReply(200, tokenPair(access: 'access-3', refresh: 'refresh-3')));
    await h.api.refresher.refresh();
    final keys = keysSent();
    expect(keys, hasLength(2));
    expect(keys[0], isNot(keys[1]));
    expect(keys[1], matches(_keyPattern));
  });

  test('retries are bounded (1 attempt + 2 retries) and end as unavailable, keeping the session', () async {
    h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionTimeout));
    expect(await h.api.refresher.refresh(), isA<RefreshUnavailable>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(3));
    expect(keysSent().toSet(), hasLength(1));
    expect(await h.tokens.read(), isNotNull);
    await Future<void>.delayed(Duration.zero);
    expect(expiredEvents, 0);
  });

  test('a gateway error is retried; a rejection and other statuses are not', () async {
    var attempt = 0;
    h.adapter.on('POST', _path, (_) => ++attempt == 1 ? FakeReply.problem(503, 'unavailable') : FakeReply(200, tokenPair()));
    expect(await h.api.refresher.refresh(), isA<RefreshSucceeded>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(2));

    h.adapter.requests.clear();
    h.adapter.on('POST', _path, (_) => FakeReply.problem(500, 'internal_error'));
    expect(await h.api.refresher.refresh(), isA<RefreshUnavailable>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(1), reason: '500 is not retried in-operation');

    h.adapter.requests.clear();
    h.adapter.on('POST', _path, (_) => FakeReply.problem(401, 'invalid_refresh_token'));
    expect(await h.api.refresher.refresh(), isA<RefreshRejected>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(1));
  });

  test('after a failed operation the same unrotated token keeps its key (the server may have rotated)', () async {
    h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
    await h.api.refresher.refresh();
    h.elapsed += const Duration(seconds: 10);
    await h.api.refresher.refresh();
    expect(keysSent().toSet(), hasLength(1));
  });

  test('a key older than the replay window is replaced', () async {
    h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
    await h.api.refresher.refresh();
    h.elapsed += const Duration(seconds: 51);
    await h.api.refresher.refresh();
    expect(keysSent().toSet(), hasLength(2));
  });

  test('no retry is sent once the replay window has passed', () async {
    h.adapter.on('POST', _path, (_) {
      h.elapsed += const Duration(seconds: 55); // a very slow first attempt
      return const FakeReply.error(DioExceptionType.receiveTimeout);
    });
    expect(await h.api.refresher.refresh(), isA<RefreshUnavailable>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(1));
  });

  test('a rejection ends the key: the next operation never reuses it', () async {
    h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
    await h.api.refresher.refresh(); // issues a key for refresh-1
    h.adapter.on('POST', _path, (_) => FakeReply.problem(401, 'invalid_refresh_token'));
    await h.api.refresher.refresh();
    await h.signIn(); // the very same token string again (artificial, to isolate the key lifetime)
    h.adapter.on('POST', _path, (_) => FakeReply(200, tokenPair()));
    await h.api.refresher.refresh();
    final keys = keysSent();
    expect(keys.first, isNot(keys.last));
  });

  test('a refresh while signed out forgets the key (it does not outlive its session)', () async {
    h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
    await h.api.refresher.refresh();
    final first = keysSent().first;
    await h.tokens.clear(); // logout
    expect(await h.api.refresher.refresh(), isA<RefreshRejected>());
    await h.signIn(); // same token string again, artificial
    await h.api.refresher.refresh();
    expect(keysSent().last, isNot(first));
  });

  test('the key window follows the monotonic clock, not the wall clock', () async {
    h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
    await h.api.refresher.refresh();
    h.now = h.now.add(const Duration(hours: 3)); // the user changed the phone's clock
    await h.api.refresher.refresh();
    expect(keysSent().toSet(), hasLength(1));
  });

  test('the key never appears in a log line', () async {
    var attempt = 0;
    h.adapter.on('POST', _path, (_) => ++attempt == 1 ? const FakeReply.error(DioExceptionType.receiveTimeout) : FakeReply(200, tokenPair()));
    await h.api.refresher.refresh();
    final key = keysSent().first!;
    expect(h.logLines, isNotEmpty);
    for (final line in h.logLines) {
      expect(line, isNot(contains(key)));
      expect(line.toLowerCase(), isNot(contains('idempotency')));
    }
  });

  test('a retry is abandoned when the customer signs out meanwhile', () async {
    h.adapter.on('POST', _path, (_) async {
      await h.tokens.clear(); // logout while the first attempt is in flight
      return const FakeReply.error(DioExceptionType.receiveTimeout);
    });
    expect(await h.api.refresher.refresh(), isA<RefreshUnavailable>());
    expect(h.adapter.requestsTo('POST', _path), hasLength(1));
    expect(await h.tokens.read(), isNull);
  });
}
