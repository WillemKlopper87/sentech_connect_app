import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';

/// [locked]: a session is stored on this device but waits for a biometric
/// unlock (cold start with an enrolled biometric). Not signed in.
enum AuthStatus { initial, loading, success, failure, locked }

/// Why a biometric attempt did not sign the user in. The login page maps
/// these to (localised) guidance; [cancelled] is deliberately silent.
enum BiometricIssue { cancelled, notEnrolled, unavailable, lockedOut, permanentlyLockedOut, failed }

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.biometricsReady = false,
    this.biometricIssue,
    this.freshSignIn = false,
  });

  /// The launch state from what is stored on the device (spec §6:
  /// "biometrics only unlock an existing session").
  static AuthState restore({required User? user, required bool hasBiometricCredential, required bool biometricsAvailable}) {
    if (user == null) return const AuthState();
    if (hasBiometricCredential && biometricsAvailable) {
      return AuthState(status: AuthStatus.locked, user: user, biometricsReady: true);
    }
    return AuthState(status: AuthStatus.success, user: user);
  }

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  /// A session exists on this device (biometric credential) AND a biometric
  /// is enrolled: the login page offers "Use biometrics".
  final bool biometricsReady;
  final BiometricIssue? biometricIssue;

  /// True when this session began with an interactive sign-in in this app
  /// run; the router sends brand-new sign-ins through coverage once.
  final bool freshSignIn;

  bool get isSignedIn => status == AuthStatus.success && user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? biometricsReady,
    BiometricIssue? biometricIssue,
    bool? freshSignIn,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      biometricsReady: biometricsReady ?? this.biometricsReady,
      biometricIssue: biometricIssue,
      freshSignIn: freshSignIn ?? this.freshSignIn,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, biometricsReady, biometricIssue, freshSignIn];
}

/// Holds the signed-in session. Tokens live in secure storage behind the
/// repository; this cubit stores the [User] and the biometric marker via
/// [SessionStore]. Logout and account deletion revoke server-side and wipe
/// local personal data; a session the server rejects (see
/// `SessionEvents.expired`) signs the customer out.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._repository, {
    required this._sessionStore,
    required this._biometrics,
    required this._wiper,
    AuthState initial = const AuthState(),
    Stream<void>? sessionExpired,
  }) : super(initial) {
    _expiry = sessionExpired?.listen((_) => _onSessionExpired());
  }

  final AuthRepository _repository;
  final SessionStore _sessionStore;
  final BiometricAuthenticator _biometrics;
  final PersonalDataWiper _wiper;
  StreamSubscription<void>? _expiry;

  void _emitIfOpen(AuthState next) {
    if (!isClosed) emit(next);
  }

  /// Password sign-in from the mock phase; deleted with the password form.
  Future<void> logIn({required String mobileNumber, required String password}) async {
    _emitIfOpen(state.copyWith(status: AuthStatus.loading));
    final result = await _repository.logIn(mobileNumber: mobileNumber, password: password);
    await result.match(
      (failure) async => _emitIfOpen(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (user) => signedIn(user, fresh: true),
    );
  }

  /// Re-checks whether the "Use biometrics" button should be offered.
  Future<void> refreshBiometrics() async {
    final credential = await _sessionStore.loadBiometricCredential();
    final availability = credential == null ? BiometricAvailability.unavailable : await _biometrics.availability();
    _emitIfOpen(state.copyWith(
      biometricsReady: credential != null && availability == BiometricAvailability.available,
      errorMessage: state.errorMessage,
      biometricIssue: state.biometricIssue,
    ));
  }

  /// Unlocks the stored session. [reason] is the (localised) system prompt.
  Future<void> logInWithBiometrics({required String reason}) async {
    if (state.status == AuthStatus.loading) return; // a second tap while one attempt is running
    final credential = await _sessionStore.loadBiometricCredential();
    if (credential == null) {
      _emitIfOpen(state.copyWith(status: AuthStatus.failure, biometricsReady: false, biometricIssue: BiometricIssue.unavailable));
      return;
    }
    _emitIfOpen(state.copyWith(status: AuthStatus.loading));
    final outcome = await _biometrics.authenticate(reason: reason);
    if (outcome != BiometricResult.success) {
      _emitIfOpen(state.copyWith(status: AuthStatus.failure, biometricIssue: _issueFor(outcome)));
      return;
    }
    final result = await _repository.resumeSession();
    await result.match(
      (failure) async {
        if (failure is UnauthorizedFailure) {
          // The server revoked it: the stored session is useless now, and
          // so is the personal data that belonged to it.
          await _sessionStore.clearAll();
          await _wiper.wipeOnLogout();
          _emitIfOpen(AuthState(status: AuthStatus.failure, errorMessage: failure.message));
          return;
        }
        // Offline or a server hiccup: the session is kept, so stay locked.
        _emitIfOpen(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message));
      },
      (user) => signedIn(user, fresh: false),
    );
  }

  BiometricIssue _issueFor(BiometricResult result) => switch (result) {
        BiometricResult.cancelled => BiometricIssue.cancelled,
        BiometricResult.notEnrolled => BiometricIssue.notEnrolled,
        BiometricResult.unavailable => BiometricIssue.unavailable,
        BiometricResult.lockedOut => BiometricIssue.lockedOut,
        BiometricResult.permanentlyLockedOut => BiometricIssue.permanentlyLockedOut,
        _ => BiometricIssue.failed,
      };

  /// After an interactive sign-in ([fresh]) or a biometric unlock.
  Future<void> signedIn(User user, {required bool fresh}) async {
    await _sessionStore.saveUser(user);
    await _sessionStore.saveBiometricCredential(user.id);
    _emitIfOpen(state.copyWith(status: AuthStatus.success, user: user, freshSignIn: fresh));
  }

  /// Registration page of the mock phase; deleted with it in favour of
  /// [profileUpdated].
  Future<void> registered(User user) => signedIn(user, fresh: true);

  /// After the customer completed or edited their profile.
  Future<void> profileUpdated(User user) async {
    await _sessionStore.saveUser(user);
    _emitIfOpen(state.copyWith(status: AuthStatus.success, user: user));
  }

  /// Revokes the session server-side, forgets it (incl. the biometric
  /// credential) and wipes personal data held on the device.
  Future<void> logOut() async {
    _emitIfOpen(const AuthState()); // route guards react immediately
    await _endSession(_wiper.wipeOnLogout);
  }

  /// After a confirmed account deletion: nothing about the customer is left.
  Future<void> signOutAndWipeEverything() async {
    _emitIfOpen(const AuthState());
    await _endSession(_wiper.wipeEverything);
  }

  /// Every step runs even when an earlier one fails (an unreachable server
  /// or a storage error must never leave personal data behind). The first
  /// error is rethrown at the end so callers (the tenant switch) know the
  /// sign-out was not clean.
  Future<void> _endSession(Future<void> Function() wipe) async {
    Object? firstError;
    StackTrace? firstStack;
    for (final step in [_repository.logOut, _sessionStore.clearAll, wipe]) {
      try {
        await step();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }

  Future<void> _onSessionExpired() async {
    if (!state.isSignedIn && state.status != AuthStatus.locked) return;
    try {
      await logOut();
    } catch (_) {
      // Already signed out in the UI; a storage failure here has no caller
      // to report to (and must not become an unhandled async error).
    }
  }

  @override
  Future<void> close() async {
    await _expiry?.cancel();
    return super.close();
  }
}
