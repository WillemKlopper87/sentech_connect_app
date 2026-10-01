import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

enum OtpStep { phone, code }

enum OtpLoginStatus { idle, sending, verifying, failure, verified }

/// Emits the seconds left, counting down to 0.
typedef CountdownTicker = Stream<int> Function(int seconds);

/// Verifies the code and, in the app, signs the customer in as part of the
/// same operation (`AuthCubit.signInWithOtp`). Defaults to the repository's
/// plain `verifyOtp`.
typedef CodeVerifier = Future<Either<Failure, User>> Function(OtpChallenge challenge, String code);

Stream<int> _secondsTicker(int seconds) =>
    Stream<int>.periodic(const Duration(seconds: 1), (i) => seconds - i - 1).take(seconds);

class OtpLoginState extends Equatable {
  const OtpLoginState({
    this.step = OtpStep.phone,
    this.status = OtpLoginStatus.idle,
    this.challenge,
    this.failure,
    this.resendIn = 0,
    this.user,
  });

  final OtpStep step;
  final OtpLoginStatus status;
  final OtpChallenge? challenge;
  final Failure? failure;

  /// Seconds until "Resend code" is enabled.
  final int resendIn;
  final User? user;

  bool get busy => status == OtpLoginStatus.sending || status == OtpLoginStatus.verifying;

  /// A status change replaces [failure] (null unless given); a countdown
  /// tick keeps it.
  OtpLoginState copyWith({OtpStep? step, OtpLoginStatus? status, OtpChallenge? challenge, Failure? failure, int? resendIn, User? user}) =>
      OtpLoginState(
        step: step ?? this.step,
        status: status ?? this.status,
        challenge: challenge ?? this.challenge,
        failure: status != null ? failure : (failure ?? this.failure),
        resendIn: resendIn ?? this.resendIn,
        user: user ?? this.user,
      );

  @override
  List<Object?> get props => [step, status, challenge, failure, resendIn, user];
}

/// Phone number -> SMS code -> signed in. Sign-in and sign-up are the same
/// flow: the platform creates the account on the first verified code. The
/// state is `verified` only once the [verifier] (which also signs the
/// customer in) has finished.
class OtpLoginCubit extends Cubit<OtpLoginState> {
  OtpLoginCubit(
    this._repository, {
    this.resendCooldown = const Duration(seconds: 30),
    CountdownTicker? ticker,
    this._verifier,
  })  : _ticker = ticker ?? _secondsTicker,
        super(const OtpLoginState());

  static final _sixDigits = RegExp(r'^\d{6}$');

  final AuthRepository _repository;
  final Duration resendCooldown;
  final CountdownTicker _ticker;
  final CodeVerifier? _verifier;
  StreamSubscription<int>? _countdown;

  Future<void> submitPhone(String input) async {
    if (state.busy) return;
    if (normaliseZaMobile(input) == null) {
      emit(state.copyWith(
        status: OtpLoginStatus.failure,
        failure: const ValidationFailure('Enter a valid South African mobile number.', 'invalid_phone'),
      ));
      return;
    }
    await _send(input);
  }

  Future<void> resend() async {
    final challenge = state.challenge;
    if (state.busy || challenge == null || state.resendIn > 0) return;
    await _send(challenge.phoneE164);
  }

  Future<void> _send(String phone) async {
    emit(state.copyWith(status: OtpLoginStatus.sending));
    final result = await _repository.requestOtp(phoneNumber: phone);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: OtpLoginStatus.failure, failure: failure)),
      (challenge) {
        emit(state.copyWith(
          step: OtpStep.code,
          status: OtpLoginStatus.idle,
          challenge: challenge,
          resendIn: resendCooldown.inSeconds,
        ));
        _startCountdown();
      },
    );
  }

  void _startCountdown() {
    _countdown?.cancel();
    _countdown = _ticker(resendCooldown.inSeconds).listen((left) {
      if (!isClosed) emit(state.copyWith(resendIn: left));
    });
  }

  Future<void> submitCode(String code) async {
    final challenge = state.challenge;
    if (state.busy || challenge == null) return;
    final trimmed = code.trim();
    if (!_sixDigits.hasMatch(trimmed)) {
      emit(state.copyWith(status: OtpLoginStatus.failure, failure: const ValidationFailure('Enter the 6-digit code.', 'invalid_code')));
      return;
    }
    emit(state.copyWith(status: OtpLoginStatus.verifying));
    final verify = _verifier;
    final result = verify != null
        ? await verify(challenge, trimmed)
        : await _repository.verifyOtp(challenge: challenge, code: trimmed);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: OtpLoginStatus.failure, failure: failure)),
      (user) {
        _countdown?.cancel();
        emit(state.copyWith(status: OtpLoginStatus.verified, user: user));
      },
    );
  }

  void changeNumber() {
    _countdown?.cancel();
    emit(const OtpLoginState());
  }

  @override
  Future<void> close() async {
    await _countdown?.cancel();
    return super.close();
  }
}
