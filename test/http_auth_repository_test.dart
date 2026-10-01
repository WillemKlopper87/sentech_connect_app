import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/http_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _challenge = OtpChallenge(
  id: '3f2b8c1e-5d4a-4e6b-9c7d-1a2b3c4d5e6f',
  phoneE164: '+27821234567',
  expiresIn: Duration(minutes: 5),
);

void main() {
  late ApiHarness h;
  late HttpAuthRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpAuthRepository(h.api, tokens: h.tokens, tenant: h.tenantContext, now: () => h.now);
  });

  test('requestOtp sends tenant + E.164 phone, unauthenticated', () async {
    h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply(202, fixture('otp_request.json')));
    final challenge = (await repo.requestOtp(phoneNumber: '082 123 4567')).getOrElse((f) => throw StateError(f.message));
    expect(challenge, _challenge);
    final sent = h.adapter.requests.single;
    expect(sent.data, {'tenant': 'sentech', 'phone': '+27821234567'});
    expect(sent.headers.containsKey('Authorization'), isFalse);
  });

  test('an invalid number is rejected before any request', () async {
    final result = await repo.requestOtp(phoneNumber: '011 123 4567');
    expect((result.match((f) => f, (_) => null)! as ValidationFailure).code, 'invalid_phone');
    expect(h.adapter.requests, isEmpty);
  });

  test('rate limiting surfaces RateLimitedFailure with Retry-After', () async {
    h.adapter.on('POST', '/v1/auth/otp/request', (_) => FakeReply.problem(429, 'rate_limited', headers: {
          'retry-after': ['600'],
        }));
    final failure = (await repo.requestOtp(phoneNumber: '0821234567')).match((f) => f, (_) => null);
    expect((failure! as RateLimitedFailure).retryAfter, const Duration(minutes: 10));
  });

  test('verifyOtp stores the tenant-bound tokens and loads the profile', () async {
    h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile.json')));
    final user = (await repo.verifyOtp(challenge: _challenge, code: '123456')).getOrElse((f) => throw StateError(f.message));

    expect(user.id, ApiHarness.customerId);
    expect(user.fullName, '');
    expect(user.mobileNumber, '+27821234567');
    expect(h.adapter.requestsTo('POST', '/v1/auth/otp/verify').single.data, {
      'tenant': 'sentech',
      'challenge_id': _challenge.id,
      'code': '123456',
    });
    expect(h.adapter.requestsTo('GET', '/v1/me/profile').single.headers['Authorization'], 'Bearer access-2');
    final stored = (await h.tokens.read())!;
    expect(stored.tenantSlug, 'sentech');
    expect(stored.accessExpiresAt, h.now.add(const Duration(seconds: 900)));
  });

  test('a wrong code keeps the API code and stores nothing', () async {
    h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply.problem(400, 'otp_invalid', detail: 'The code is invalid or has expired.'));
    final failure = (await repo.verifyOtp(challenge: _challenge, code: '000000')).match((f) => f, (_) => null);
    expect((failure! as ValidationFailure).code, 'otp_invalid');
    expect(await h.tokens.read(), isNull);
  });

  test('a malformed code never reaches the server', () async {
    final failure = (await repo.verifyOtp(challenge: _challenge, code: '12ab')).match((f) => f, (_) => null);
    expect((failure! as ValidationFailure).code, 'invalid_code');
    expect(h.adapter.requests, isEmpty);
  });

  test('resumeSession proves the stored refresh token and reloads the profile', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile_complete.json')));
    final user = (await repo.resumeSession()).getOrElse((f) => throw StateError(f.message));
    expect(user.fullName, 'Thandi Mokoena');
    expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh').single.data, {'tenant': 'sentech', 'refresh_token': 'refresh-1'});
  });

  test('resumeSession with a revoked refresh token fails and forgets the tokens', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply.problem(401, 'invalid_refresh_token'));
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(await h.tokens.read(), isNull);
  });

  test('resumeSession offline is a NetworkFailure and keeps the tokens', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => const FakeReply.error(DioExceptionType.connectionTimeout));
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<NetworkFailure>());
    expect(await h.tokens.read(), isNotNull);
  });

  test('resumeSession keeps a proven session when only the profile cannot be loaded right now', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) => const FakeReply.error(DioExceptionType.connectionError));
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<NetworkFailure>());
    expect((await h.tokens.read())!.accessToken, 'access-2');
  });

  test('verifyOtp never keeps tokens when the profile cannot be loaded', () async {
    h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) => const FakeReply.error(DioExceptionType.connectionError));
    expect((await repo.verifyOtp(challenge: _challenge, code: '123456')).isLeft(), isTrue);
    expect(await h.tokens.read(), isNull);
  });

  test('logOut revokes the refresh family with the bearer token, then forgets the tokens', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply(204));
    await repo.logOut();
    final sent = h.adapter.requestsTo('POST', '/v1/auth/logout').single;
    expect(sent.data, {'refresh_token': 'refresh-1'});
    expect(sent.headers['Authorization'], 'Bearer access-1');
    expect(await h.tokens.read(), isNull);
  });

  test('logOut forgets the tokens even when the server is unreachable (offline logout is best effort: no revoke)', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply.error(DioExceptionType.connectionError));
    await repo.logOut();
    expect(h.adapter.requestsTo('POST', '/v1/auth/logout'), hasLength(1), reason: 'one attempt, not retried');
    expect(await h.tokens.read(), isNull);
    expect(h.store.snapshot.containsKey('auth_tokens'), isFalse);
  });

  group('logOut with an expired access token (R-m9)', () {
    test('refreshes first and revokes with the NEW refresh token and bearer', () async {
      await h.signIn(validFor: const Duration(seconds: 5)); // inside the refresh margin
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair(access: 'access-2', refresh: 'refresh-2')));
      h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply(204));
      await repo.logOut();
      final sent = h.adapter.requestsTo('POST', '/v1/auth/logout').single;
      expect(sent.data, {'refresh_token': 'refresh-2'}, reason: 'the spent token must never be sent');
      expect(sent.headers['Authorization'], 'Bearer access-2');
      expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), hasLength(1));
      expect(await h.tokens.read(), isNull);
    });

    test('an already expired token behaves the same', () async {
      await h.signIn(validFor: const Duration(minutes: -1));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
      h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply(204));
      await repo.logOut();
      expect(h.adapter.requestsTo('POST', '/v1/auth/logout').single.data, {'refresh_token': 'refresh-2'});
    });

    test('a fresh token is not refreshed first', () async {
      await h.signIn();
      h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply(204));
      await repo.logOut();
      expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), isEmpty);
    });

    test('a rejected refresh means the server already ended it: no logout call, tokens gone', () async {
      await h.signIn(validFor: const Duration(seconds: 5));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply.problem(401, 'invalid_refresh_token'));
      await repo.logOut();
      expect(h.adapter.requestsTo('POST', '/v1/auth/logout'), isEmpty);
      expect(await h.tokens.read(), isNull);
    });

    test('an unreachable server during the refresh still wipes locally (best effort, no revoke)', () async {
      await h.signIn(validFor: const Duration(seconds: 5));
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) => const FakeReply.error(DioExceptionType.connectionError));
      await repo.logOut();
      expect(h.adapter.requestsTo('POST', '/v1/auth/logout'), isEmpty);
      expect(await h.tokens.read(), isNull);
      expect(h.store.snapshot.containsKey('auth_tokens'), isFalse);
    });

    test('the whole revoke is bounded in time and a late refresh cannot bring the session back', () async {
      final slow = HttpAuthRepository(
        h.api,
        tokens: h.tokens,
        tenant: h.tenantContext,
        now: () => h.now,
        logoutTimeout: const Duration(milliseconds: 50),
      );
      await h.signIn(validFor: const Duration(seconds: 5));
      final gate = Completer<void>();
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) async {
        await gate.future; // the network never answers in time
        return FakeReply(200, tokenPair());
      });
      final stopwatch = Stopwatch()..start();
      await slow.logOut();
      expect(stopwatch.elapsed, lessThan(const Duration(seconds: 3)));
      expect(await h.tokens.read(), isNull);

      gate.complete(); // the late reply must be discarded, not written back
      for (var i = 0; i < 20; i++) {
        await Future<void>.delayed(Duration.zero);
      }
      expect(await h.tokens.read(), isNull);
      expect(h.store.snapshot.containsKey('auth_tokens'), isFalse);
    });
  });

  group('sessionMatches', () {
    const user = User(id: ApiHarness.customerId, fullName: '', mobileNumber: '');

    test('true for this tenant and this customer', () async {
      await h.signIn();
      expect(await repo.sessionMatches(tenantSlug: 'sentech', user: user), isTrue);
    });

    test('false without tokens, for another tenant, or for another customer', () async {
      expect(await repo.sessionMatches(tenantSlug: 'sentech', user: user), isFalse);
      await h.signIn();
      expect(await repo.sessionMatches(tenantSlug: 'acme-wifi', user: user), isFalse);
      expect(await repo.sessionMatches(tenantSlug: 'sentech', user: const User(id: 'other', fullName: '', mobileNumber: '')), isFalse);
    });
  });

  test('resumeSession with tokens issued for another tenant fails, sends nothing and forgets them', () async {
    await h.signIn(tenant: 'acme-wifi'); // the active tenant is sentech
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(h.adapter.requests, isEmpty);
    expect(await h.tokens.read(), isNull);
  });

  test('a logout racing the profile request is not undone by resumeSession', () async {
    await h.signIn();
    h.adapter.on('POST', '/v1/auth/token/refresh', (_) => FakeReply(200, tokenPair()));
    h.adapter.on('GET', '/v1/me/profile', (_) async {
      await h.tokens.clear(); // the customer logs out while the profile is loading
      return FakeReply(200, fixture('profile_complete.json'));
    });
    expect((await repo.resumeSession()).match((f) => f, (_) => null), isA<UnauthorizedFailure>());
    expect(await h.tokens.read(), isNull);
  });

  test('verifyOtp: the per-account failure cap (429) surfaces as RateLimitedFailure with Retry-After', () async {
    h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply.problem(429, 'rate_limited', headers: {
          'retry-after': ['120'],
        }));
    final failure = (await repo.verifyOtp(challenge: _challenge, code: '123456')).match((f) => f, (_) => null);
    expect((failure! as RateLimitedFailure).retryAfter, const Duration(minutes: 2));
    expect(await h.tokens.read(), isNull);
  });

  group('signing in as a different customer revokes the replaced session (R-m9)', () {
    Future<void> signInOther() => h.tokens.write(AuthTokens(
          accessToken: 'old-access',
          refreshToken: 'old-refresh',
          accessExpiresAt: h.now.add(const Duration(minutes: 10)),
          customerId: 'previous-customer',
          tenantSlug: 'sentech',
        ));

    test("the previous customer's refresh family is revoked before the new tokens are stored", () async {
      await signInOther();
      h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply(204));
      h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply(200, tokenPair()));
      h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile.json')));
      expect((await repo.verifyOtp(challenge: _challenge, code: '123456')).isRight(), isTrue);
      final revoke = h.adapter.requestsTo('POST', '/v1/auth/logout').single;
      expect(revoke.data, {'refresh_token': 'old-refresh'});
      expect(revoke.headers['Authorization'], 'Bearer old-access');
      expect((await h.tokens.read())!.customerId, ApiHarness.customerId);
    });

    test('a failed revoke does not stop the sign-in', () async {
      await signInOther();
      h.adapter.on('POST', '/v1/auth/logout', (_) => const FakeReply.error(DioExceptionType.connectionError));
      h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply(200, tokenPair()));
      h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile.json')));
      expect((await repo.verifyOtp(challenge: _challenge, code: '123456')).isRight(), isTrue);
    });

    test('the same customer signing in again triggers no revoke', () async {
      await h.signIn();
      h.adapter.on('POST', '/v1/auth/otp/verify', (_) => FakeReply(200, tokenPair()));
      h.adapter.on('GET', '/v1/me/profile', (_) => FakeReply(200, fixture('profile.json')));
      await repo.verifyOtp(challenge: _challenge, code: '123456');
      expect(h.adapter.requestsTo('POST', '/v1/auth/logout'), isEmpty);
    });
  });
}
