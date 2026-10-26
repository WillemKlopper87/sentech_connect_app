import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/otp_login_cubit.dart' show CountdownTicker;
import 'package:sentech_connect_app/features/privacy/domain/repositories/privacy_repository.dart';

/// [deleteCodeSent]: the SMS code for deleting the account is on its way and
/// the dialog asks for it ([PrivacyActionsState.deleteChallenge] is set).
enum PrivacyActionStatus { idle, working, exportRequested, deleteCodeSent, deleted, failed }

/// Which request a [PrivacyActionStatus.working] or `failed` state belongs to.
enum PrivacyAction { export, deleteCode, delete }

class PrivacyActionsState extends Equatable {
  const PrivacyActionsState({
    this.status = PrivacyActionStatus.idle,
    this.receipt,
    this.failure,
    this.action,
    this.deleteChallenge,
    this.resendIn = 0,
    this.rateLimited = false,
  });

  final PrivacyActionStatus status;
  final PrivacyRequestReceipt? receipt;

  /// Why the last action failed (set with [PrivacyActionStatus.failed]); the
  /// page maps it to a customer-facing message.
  final Failure? failure;

  /// What was being done when [status] is `working` or `failed`.
  final PrivacyAction? action;

  /// The delete code that is waiting to be entered. Kept through a wrong code
  /// so the customer can try again; cleared by [PrivacyActionsCubit.cancelDelete]
  /// and once the account is deleted.
  final DeleteChallenge? deleteChallenge;

  /// Seconds until "Send the code again" is enabled.
  final int resendIn;

  /// The server answered 429: [resendIn] is the wait it asked for and sending,
  /// resending and deleting stay disabled until it is over.
  final bool rateLimited;

  bool get locked => rateLimited && resendIn > 0;
  bool get working => status == PrivacyActionStatus.working;

  /// The delete dialog can go no further than showing [failure] (for example
  /// "contact support" or "cancel your service first"): retrying cannot help.
  bool get deleteBlocked => failure is DeleteCodeUnavailableFailure || failure is ActiveServiceExistsFailure;

  PrivacyActionsState copyWith({
    PrivacyActionStatus? status,
    PrivacyRequestReceipt? receipt,
    Failure? failure,
    PrivacyAction? action,
    DeleteChallenge? deleteChallenge,
    int? resendIn,
    bool? rateLimited,
    bool clearFailure = false,
  }) => PrivacyActionsState(
    status: status ?? this.status,
    receipt: receipt ?? this.receipt,
    failure: clearFailure ? null : (failure ?? this.failure),
    action: action ?? this.action,
    deleteChallenge: deleteChallenge ?? this.deleteChallenge,
    resendIn: resendIn ?? this.resendIn,
    rateLimited: rateLimited ?? this.rateLimited,
  );

  @override
  List<Object?> get props => [status, receipt, failure, action, deleteChallenge, resendIn, rateLimited];
}

Stream<int> _secondsTicker(int seconds) =>
    Stream<int>.periodic(const Duration(seconds: 1), (i) => seconds - i - 1).take(seconds);

/// Data-subject actions from the Account tab.
///
/// Deleting the account is two steps (the platform wants a fresh code from the
/// phone on the account, not just the session): [requestDeleteCode] sends the
/// SMS, then [deleteAccount] sends the code. [onAccountDeleted] runs only
/// after the server answered 204, and performs the local wipe + sign-out
/// (wired to `AuthCubit.signOutAndWipeEverything` by the page). Any refusal,
/// including a wrong code, leaves everything on the device untouched.
class PrivacyActionsCubit extends Cubit<PrivacyActionsState> {
  PrivacyActionsCubit(
    this._repository, {
    required this.onAccountDeleted,
    this.resendCooldown = const Duration(seconds: 30),
    CountdownTicker? ticker,
  })  : _ticker = ticker ?? _secondsTicker,
        super(const PrivacyActionsState());

  static final _sixDigits = RegExp(r'^\d{6}$');

  final PrivacyRepository _repository;
  final Future<void> Function() onAccountDeleted;
  final Duration resendCooldown;
  final CountdownTicker _ticker;
  StreamSubscription<int>? _countdown;

  Future<void> requestDataExport() async {
    if (state.working) return;
    emit(const PrivacyActionsState(status: PrivacyActionStatus.working, action: PrivacyAction.export));
    final result = await _repository.requestDataExport();
    if (isClosed) return;
    emit(result.match(
      (failure) => PrivacyActionsState(status: PrivacyActionStatus.failed, failure: failure, action: PrivacyAction.export),
      (receipt) => PrivacyActionsState(status: PrivacyActionStatus.exportRequested, receipt: receipt),
    ));
  }

  /// Step 1 (and "send the code again"): asks for the SMS code. Asking again
  /// replaces the earlier code on the server.
  Future<void> requestDeleteCode() async {
    if (state.working || state.locked || state.deleteBlocked) return;
    final previous = state.deleteChallenge;
    emit(PrivacyActionsState(
      status: PrivacyActionStatus.working,
      action: PrivacyAction.deleteCode,
      deleteChallenge: previous,
    ));
    final result = await _repository.requestDeleteChallenge();
    if (isClosed) return;
    result.match(
      (failure) => _fail(failure, PrivacyAction.deleteCode, previous),
      (challenge) {
        emit(PrivacyActionsState(
          status: PrivacyActionStatus.deleteCodeSent,
          deleteChallenge: challenge,
          resendIn: resendCooldown.inSeconds,
        ));
        _startCountdown(resendCooldown.inSeconds);
      },
    );
  }

  /// Step 2: deletes the account with the 6-digit [code] of the SMS. Returns
  /// true once the server accepted it and the local wipe has run (the page
  /// that hosts this cubit is usually gone by then, so callers cannot rely on
  /// a final state).
  Future<bool> deleteAccount(String code) async {
    final challenge = state.deleteChallenge;
    if (state.working || state.locked || challenge == null) return false;
    final trimmed = code.trim();
    if (!_sixDigits.hasMatch(trimmed)) {
      emit(state.copyWith(
        status: PrivacyActionStatus.failed,
        action: PrivacyAction.delete,
        failure: const ValidationFailure('Enter the 6-digit code.', 'invalid_code'),
      ));
      return false;
    }
    emit(PrivacyActionsState(
      status: PrivacyActionStatus.working,
      action: PrivacyAction.delete,
      deleteChallenge: challenge,
      resendIn: state.resendIn,
      rateLimited: state.rateLimited,
    ));
    final result = await _repository.deleteAccount(challengeId: challenge.challengeId, code: trimmed);
    final failure = result.match((f) => f, (_) => null);
    if (failure != null) {
      if (!isClosed) _fail(failure, PrivacyAction.delete, challenge);
      return false;
    }
    // Server accepted (204): now remove everything held on this device and sign out.
    _countdown?.cancel();
    await onAccountDeleted();
    if (!isClosed) emit(const PrivacyActionsState(status: PrivacyActionStatus.deleted));
    return true;
  }

  /// The customer closed the delete dialog: forget the challenge. The code
  /// that was sent stays valid on the server until it expires or is replaced.
  void cancelDelete() {
    if (state.working || state.status == PrivacyActionStatus.deleted) return;
    _countdown?.cancel();
    emit(const PrivacyActionsState());
  }

  /// A 429 locks the buttons for the wait the server asked for (never less
  /// than the normal resend cooldown), like the sign-in screen.
  void _fail(Failure failure, PrivacyAction action, DeleteChallenge? challenge) {
    if (failure is RateLimitedFailure) {
      final asked = failure.retryAfter?.inSeconds ?? 0;
      final wait = asked > resendCooldown.inSeconds ? asked : resendCooldown.inSeconds;
      emit(PrivacyActionsState(
        status: PrivacyActionStatus.failed,
        failure: failure,
        action: action,
        deleteChallenge: challenge,
        resendIn: wait,
        rateLimited: true,
      ));
      _startCountdown(wait);
      return;
    }
    emit(PrivacyActionsState(
      status: PrivacyActionStatus.failed,
      failure: failure,
      action: action,
      deleteChallenge: challenge,
      resendIn: state.resendIn,
      rateLimited: state.rateLimited,
    ));
  }

  void _startCountdown(int seconds) {
    _countdown?.cancel();
    _countdown = _ticker(seconds).listen((left) {
      if (isClosed) return;
      emit(state.copyWith(resendIn: left, rateLimited: left > 0 ? null : false));
    });
  }

  @override
  Future<void> close() async {
    await _countdown?.cancel();
    return super.close();
  }
}
