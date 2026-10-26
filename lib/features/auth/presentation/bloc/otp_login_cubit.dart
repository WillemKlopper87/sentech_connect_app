import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/utils/binding_generator.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';

enum OtpStep { phone, code }

enum OtpLoginStatus { idle, sending, verifying, failure, verified }

/// Emits the seconds left, counting down to 0.
typedef CountdownTicker = Stream<int> Function(int seconds);

/// Verifies the code and, in the app, signs the customer in as part of the
/// same operation (`AuthCubit.signInWithOtp`). Required: the repository's
/// plain `verifyOtp`; there is no fallback that skips the sign-in.
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
    this.rateLimited = false,
  });

  final OtpStep step;
  final OtpLoginStatus status;
  final OtpChallenge? challenge;
  final Failure? failure;

  /// Seconds until "Resend code" is enabled.
  final int resendIn;
  final User? user;

  /// The server answered 429: [resendIn] is then the wait it asked for, and
  /// sending, resending and verifying stay disabled until it is over.
  final bool rateLimited;

  bool get locked => rateLimited && resendIn > 0;

  bool get busy => status == OtpLoginStatus.sending || status == OtpLoginStatus.verifying;

  /// A status change replaces [failure] (null unless given); a countdown
  /// tick keeps it.
  OtpLoginState copyWith({
    OtpStep? step,
    OtpLoginStatus? status,
    OtpChallenge? challenge,
    Failure? failure,
    int? resendIn,
    User? user,
    bool? rateLimited,
  }) =>
      OtpLoginState(
        step: step ?? this.step,
        status: status ?? this.status,
        challenge: challenge ?? this.challenge,
        failure: status != null ? failure : (failure ?? this.failure),
        resendIn: resendIn ?? this.resendIn,
        user: user ?? this.user,
        rateLimited: rateLimited ?? this.rateLimited,
      );

  @override
  List<Object?> get props => [step, status, challenge, failure, resendIn, user, rateLimited];
}

/// Phone number -> SMS code -> signed in. Sign-in and sign-up are the same
/// flow: the platform creates the account on the first verified code. The
/// state is `verified` only once the [verifier] (which also signs the
/// customer in) has finished.
class OtpLoginCubit extends Cubit<OtpLoginState> {
  OtpLoginCubit(
    this._repository, {
    required this._verifier,
    this.resendCooldown = const Duration(seconds: 30),
    CountdownTicker? ticker,
    String Function()? bindingGenerator,
  })  : _ticker = ticker ?? _secondsTicker,
        _newBinding = bindingGenerator ?? BindingGenerator().call,
        super(const OtpLoginState());

  static final _sixDigits = RegExp(r'^\d{6}$');

  final AuthRepository _repository;
  final Duration resendCooldown;
  final CountdownTicker _ticker;
  final CodeVerifier _verifier;
  final String Function() _newBinding;
  StreamSubscription<int>? _countdown;

  /// The secret of the current sign-in attempt, in memory only, and the number
  /// it was made for.
  ///
  /// One attempt keeps ONE binding across resends: the API closes only the
  /// earlier codes of the SAME binding when a new code is requested, and
  /// allows at most 3 live codes per phone. A fresh binding on every resend
  /// would look like a second requester, leave the old code live and use up
  /// the phone's live-code slots (429 until a code expires). A new binding is
  /// made only when the number changes or the flow starts over.
  String? _binding;
  String? _bindingPhone;

  String _bindingFor(String phoneE164) {
    if (_binding == null || _bindingPhone != phoneE164) {
      _binding = _newBinding();
      _bindingPhone = phoneE164;
    }
    return _binding!;
  }

  void _forgetBinding() {
    _binding = null;
    _bindingPhone = null;
  }

  Future<void> submitPhone(String input) async {
    if (state.busy || state.locked) return;
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
    if (state.busy || state.locked || challenge == null || state.resendIn > 0) return;
    await _send(challenge.phoneE164);
  }

  Future<void> _send(String phone) async {
    emit(state.copyWith(status: OtpLoginStatus.sending));
    final normalised = normaliseZaMobile(phone);
    final result = await _repository.requestOtp(
      phoneNumber: phone,
      binding: _bindingFor(normalised ?? phone),
    );
    if (isClosed) return;
    result.match(
      _fail,
      (challenge) {
        emit(state.copyWith(
          step: OtpStep.code,
          status: OtpLoginStatus.idle,
          challenge: challenge,
          resendIn: resendCooldown.inSeconds,
          rateLimited: false,
        ));
        _startCountdown(resendCooldown.inSeconds);
      },
    );
  }

  /// A failed send/verify. A 429 locks the buttons for the wait the server
  /// asked for (never less than the normal resend cooldown) and runs the
  /// countdown; a spent code (the session could not be set up) goes back to
  /// the phone step so the customer is never stuck on a dead code.
  void _fail(Failure failure) {
    if (failure is HumanCheckCancelledFailure) {
      // The customer closed the Quick check: back to where they were, no error.
      emit(state.copyWith(status: OtpLoginStatus.idle));
      return;
    }
    if (failure is SessionSetupFailure) {
      _countdown?.cancel();
      _forgetBinding(); // the code is spent: the next attempt starts afresh
      emit(OtpLoginState(status: OtpLoginStatus.failure, failure: failure));
      return;
    }
    if (failure is RateLimitedFailure) {
      final wait = [failure.retryAfter?.inSeconds ?? 0, resendCooldown.inSeconds].reduce((a, b) => a > b ? a : b);
      emit(state.copyWith(status: OtpLoginStatus.failure, failure: failure, resendIn: wait, rateLimited: true));
      _startCountdown(wait);
      return;
    }
    emit(state.copyWith(status: OtpLoginStatus.failure, failure: failure));
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _countdown = _ticker(seconds).listen((left) {
      if (!isClosed) emit(state.copyWith(resendIn: left, rateLimited: left > 0 ? null : false));
    });
  }

  Future<void> submitCode(String code) async {
    final challenge = state.challenge;
    if (state.busy || state.locked || state.status == OtpLoginStatus.verified || challenge == null) return;
    final trimmed = code.trim();
    if (!_sixDigits.hasMatch(trimmed)) {
      emit(state.copyWith(status: OtpLoginStatus.failure, failure: const ValidationFailure('Enter the 6-digit code.', 'invalid_code')));
      return;
    }
    emit(state.copyWith(status: OtpLoginStatus.verifying));
    final result = await _verifier(challenge, trimmed);
    if (isClosed) return;
    result.match(
      _fail,
      (user) {
        _countdown?.cancel();
        _forgetBinding();
        emit(state.copyWith(status: OtpLoginStatus.verified, user: user));
      },
    );
  }

  void changeNumber() {
    _forgetBinding();
    // A server wait belongs to this login flow, even if the phone changes.
    // Keep its running countdown while discarding the old challenge.
    if (state.locked) {
      emit(OtpLoginState(
        status: OtpLoginStatus.failure,
        failure: state.failure,
        resendIn: state.resendIn,
        rateLimited: true,
      ));
      return;
    }
    _countdown?.cancel();
    emit(const OtpLoginState());
  }

  @override
  Future<void> close() async {
    await _countdown?.cancel();
    return super.close();
  }
}
