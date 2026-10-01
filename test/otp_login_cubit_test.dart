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

  @override
  Future<Either<Failure, OtpChallenge>> requestOtp({required String phoneNumber}) {
    requests++;
    return super.requestOtp(phoneNumber: phoneNumber);
  }
}

Stream<int> _instantTicker(int seconds) => Stream.fromIterable([for (var i = seconds - 1; i >= 0; i--) i]);

void main() {
  late _CountingRepo repo;

  setUp(() => repo = _CountingRepo());

  test('a valid number moves to the code step and runs the resend countdown', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('082 123 4567');
    expect(cubit.state.step, OtpStep.code);
    expect(cubit.state.challenge!.phoneE164, '+27821234567');
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.resendIn, 0);
    await cubit.close();
  });

  test('an invalid number is rejected locally and never sent', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('011 123 4567');
    expect(cubit.state.status, OtpLoginStatus.failure);
    expect((cubit.state.failure! as ValidationFailure).code, 'invalid_phone');
    expect(repo.requests, 0);
    await cubit.close();
  });

  test('resend is ignored while the countdown runs', () async {
    final never = StreamController<int>();
    final cubit = OtpLoginCubit(repo, ticker: (_) => never.stream);
    await cubit.submitPhone('0821234567');
    expect(cubit.state.resendIn, 30);
    await cubit.resend();
    expect(repo.requests, 1);
    await cubit.close();
    await never.close();
  });

  test('resend after the countdown asks for a new code', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await Future<void>.delayed(Duration.zero);
    await cubit.resend();
    expect(repo.requests, 2);
    await cubit.close();
  });

  test('a wrong code reports otp_invalid and stays on the code step', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode(MockAuthRepository.rejectedDemoCode);
    expect(cubit.state.step, OtpStep.code);
    expect((cubit.state.failure! as ValidationFailure).code, 'otp_invalid');
    await cubit.close();
  });

  test('a malformed code is rejected locally', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('12 34');
    expect((cubit.state.failure! as ValidationFailure).code, 'invalid_code');
    await cubit.close();
  });

  test('a correct code emits the signed-in user', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
    await cubit.submitPhone('0821234567');
    await cubit.submitCode('123456');
    expect(cubit.state.status, OtpLoginStatus.verified);
    expect(cubit.state.user!.mobileNumber, '+27821234567');
    await cubit.close();
  });

  test('changeNumber returns to the phone step', () async {
    final cubit = OtpLoginCubit(repo, ticker: _instantTicker);
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
}
