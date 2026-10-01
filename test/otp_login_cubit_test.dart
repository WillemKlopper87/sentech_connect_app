import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/mock_auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/otp_login_cubit.dart';

class _CountingRepo extends MockAuthRepository {
  _CountingRepo() : super(latency: Duration.zero);

  int requests = 0;
  Failure? requestFailure;

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) {
    requests++;
    final failure = requestFailure;
    if (failure != null) return Future.value(Left(failure));
    return super.requestOtp(phoneNumber: phoneNumber);
  }
}

CodeVerifier _verifier(MockAuthRepository repo) => (challenge, code) => repo.verifyOtp(challenge: challenge, code: code);

Stream<int> _instantTicker(int seconds) => Stream.fromIterable([for (var i = seconds - 1; i >= 0; i--) i]);

void main() {
  late _CountingRepo repo;

  setUp(() => repo = _CountingRepo());

  test('a valid number moves to the code step and runs the resend countdown', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('082 123 4567');
    expect(cubit.state.step, OtpStep.code);
    expect(cubit.state.challenge!.phoneE164, '+27821234567');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.resendIn, 0);
    await cubit.close();
  });

  test('an invalid number is rejected locally and never sent', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('011 123 4567');
    expect(cubit.state.status, OtpLoginStatus.failure);
    expect((cubit.state.failure! as ValidationFailure).code, 'invalid_phone');
    expect(repo.requests, 0);
    await cubit.close();
  });

  test('resend is ignored while the countdown runs', () async {
    final never = StreamController<int>();
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: (_) => never.stream);
    await cubit.submitPhone('0821234567');
    expect(cubit.state.resendIn, 30);
    await cubit.resend();
    expect(repo.requests, 1);
    await cubit.close();
    await never.close();
  });

  test('resend after the countdown asks for a new code', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await Future<void>.delayed(Duration.zero);
    await cubit.resend();
    expect(repo.requests, 2);
    await cubit.close();
  });

  test('a wrong code reports otp_invalid and stays on the code step', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode(MockAuthRepository.rejectedDemoCode);
    expect(cubit.state.step, OtpStep.code);
    expect((cubit.state.failure! as ValidationFailure).code, 'otp_invalid');
    await cubit.close();
  });

  test('a malformed code is rejected locally', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('12 34');
    expect((cubit.state.failure! as ValidationFailure).code, 'invalid_code');
    await cubit.close();
  });

  test('a correct code emits the signed-in user', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('123456');
    expect(cubit.state.status, OtpLoginStatus.verified);
    expect(cubit.state.user!.mobileNumber, '+27821234567');
    await cubit.close();
  });

  test('changeNumber returns to the phone step', () async {
    final cubit = OtpLoginCubit(repo, verifier: _verifier(repo), ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    cubit.changeNumber();
    expect(cubit.state, const OtpLoginState());
    await cubit.close();
  });
  test('a verifier (verify + sign-in as one operation) decides the outcome: verified only after it completes', () async {
    final gate = Completer<void>();
    final cubit = OtpLoginCubit(
      repo,
      ticker: _instantTicker,
      verifier: (challenge, code) async {
        await gate.future;
        return Right(User(id: 'u1', fullName: 'Thandi', mobileNumber: challenge.phoneE164));
      },
    );
    await cubit.submitPhone('0821234567');
    final pending = cubit.submitCode('123456');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.status, OtpLoginStatus.verifying);
    gate.complete();
    await pending;
    expect(cubit.state.status, OtpLoginStatus.verified);
    expect(cubit.state.user!.id, 'u1');
    await cubit.close();
  });

  test('a failing verifier (e.g. terms not accepted) keeps the code step with its failure', () async {
    final cubit = OtpLoginCubit(
      repo,
      ticker: _instantTicker,
      verifier: (_, _) async => const Left(ValidationFailure('Accept the Terms of Service to continue.', 'terms_not_accepted')),
    );
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('123456');
    expect(cubit.state.step, OtpStep.code);
    expect(cubit.state.status, OtpLoginStatus.failure);
    expect((cubit.state.failure! as ValidationFailure).code, 'terms_not_accepted');
    await cubit.close();
  });
  group('rate limiting (429)', () {
    late StreamController<int> ticks;

    setUp(() => ticks = StreamController<int>.broadcast());
    tearDown(() => ticks.close());

    OtpLoginCubit build(CodeVerifier verifier) => OtpLoginCubit(repo, verifier: verifier, ticker: (_) => ticks.stream);

    for (final source in ['send', 'verify', 'resend']) {
      test('changeNumber preserves the $source rate limit until its original countdown ends', () async {
        const failure = RateLimitedFailure('slow down', Duration(seconds: 90));
        final cubit = build((_, _) async => const Left(failure));
        if (source == 'send') repo.requestFailure = failure;
        await cubit.submitPhone('0821234567');
        if (source == 'verify') await cubit.submitCode('123456');
        if (source == 'resend') {
          ticks.add(0);
          await Future<void>.delayed(Duration.zero);
          repo.requestFailure = failure;
          await cubit.resend();
        }
        final requests = repo.requests;
        ticks.add(45);
        await Future<void>.delayed(Duration.zero);

        cubit.changeNumber();
        expect(cubit.state.step, OtpStep.phone);
        expect(cubit.state.challenge, isNull);
        expect(cubit.state.failure, failure);
        expect(cubit.state.resendIn, 45, reason: 'changing number must not restart or clear the wait');
        expect(cubit.state.locked, isTrue);
        repo.requestFailure = null;
        await cubit.submitPhone('0821234567');
        await cubit.submitPhone('0831234567');
        expect(repo.requests, requests, reason: 'same and different numbers remain locked');

        ticks.add(1);
        await Future<void>.delayed(Duration.zero);
        cubit.changeNumber();
        await cubit.submitPhone('0821234567');
        expect(cubit.state.resendIn, 1);
        expect(repo.requests, requests);
        ticks.add(0);
        await Future<void>.delayed(Duration.zero);
        await cubit.submitPhone('0821234567');
        expect(repo.requests, requests + 1);
        expect(cubit.state.step, OtpStep.code);
        await cubit.close();
      });
    }

    test('a 429 on send waits as long as the server asked, locks sending, and counts down', () async {
      repo.requestFailure = const RateLimitedFailure('slow down', Duration(seconds: 90));
      final cubit = build(_verifier(repo));
      await cubit.submitPhone('0821234567');
      expect(cubit.state.step, OtpStep.phone);
      expect(cubit.state.status, OtpLoginStatus.failure);
      expect(cubit.state.failure, isA<RateLimitedFailure>());
      expect(cubit.state.resendIn, 90);
      expect(cubit.state.locked, isTrue);

      await cubit.submitPhone('0821234567');
      expect(repo.requests, 1, reason: 'no second request while locked');

      ticks.add(10);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.resendIn, 10);
      expect(cubit.state.locked, isTrue);
      ticks.add(0);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state.locked, isFalse);

      repo.requestFailure = null;
      await cubit.submitPhone('0821234567');
      expect(cubit.state.step, OtpStep.code);
      await cubit.close();
    });

    test('the wait is never shorter than the normal resend cooldown', () async {
      repo.requestFailure = const RateLimitedFailure('slow down', Duration(seconds: 3));
      final cubit = build(_verifier(repo));
      await cubit.submitPhone('0821234567');
      expect(cubit.state.resendIn, 30);
      repo.requestFailure = const RateLimitedFailure();
      await cubit.close();

      final cubit2 = build(_verifier(repo));
      await cubit2.submitPhone('0821234567');
      expect(cubit2.state.resendIn, 30, reason: 'no Retry-After at all');
      await cubit2.close();
    });

    test('a 429 on verify locks verifying and resending, and keeps the code step', () async {
      var verifies = 0;
      final cubit = build((_, _) async {
        verifies++;
        return const Left(RateLimitedFailure('slow down', Duration(seconds: 120)));
      });
      await cubit.submitPhone('0821234567');
      await cubit.submitCode('123456');
      expect(cubit.state.step, OtpStep.code);
      expect(cubit.state.resendIn, 120);
      expect(cubit.state.locked, isTrue);

      await cubit.submitCode('123456');
      await cubit.resend();
      expect(verifies, 1);
      expect(repo.requests, 1);
      await cubit.close();
    });

    test('a 429 on resend locks for the server wait', () async {
      final cubit = build(_verifier(repo));
      await cubit.submitPhone('0821234567');
      ticks.add(0); // the normal cooldown is over
      await Future<void>.delayed(Duration.zero);
      repo.requestFailure = const RateLimitedFailure('slow down', Duration(seconds: 60));
      await cubit.resend();
      expect(cubit.state.resendIn, 60);
      expect(cubit.state.locked, isTrue);
      await cubit.close();
    });
  });

  test('a code that was accepted but could not be turned into a session sends the customer back to the phone step', () async {
    final cubit = OtpLoginCubit(repo, verifier: (_, _) async => const Left(SessionSetupFailure()), ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('123456');
    expect(cubit.state.step, OtpStep.phone);
    expect(cubit.state.status, OtpLoginStatus.failure);
    expect(cubit.state.failure, isA<SessionSetupFailure>());
    expect(cubit.state.challenge, isNull, reason: 'the spent challenge is gone: a new code is needed');
    await cubit.close();
  });
}
