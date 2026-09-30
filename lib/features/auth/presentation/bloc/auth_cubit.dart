import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';

enum AuthStatus { initial, loading, success, failure }

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

  final AuthStatus status;
  final User? user;
  final String? errorMessage;

  /// True when a session was previously established on this device (a
  /// biometric credential exists) *and* the device has an enrolled biometric.
  /// The login page only offers "Use biometrics" when this is true.
  final bool biometricsReady;
  final BiometricIssue? biometricIssue;

  /// True when this session began with an interactive password login or
  /// registration in this app run (not a restored session or biometrics);
  /// the router uses it to send brand-new sign-ins through the coverage
  /// check once.
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

/// The signed-in session is persisted through [SessionStore] (secure
/// storage) so a customer isn't logged out every time the app is closed —
/// there's no backend session/token yet, so this is a device-local
/// "remember me" rather than a real auth token refresh.
class AuthCubit extends Cubit<AuthState> {
  AuthCubit(
    this._repository, {
    required this._sessionStore,
    required this._biometrics,
    required this._wiper,
    AuthState initial = const AuthState(),
  }) : super(initial);

  final AuthRepository _repository;
  final SessionStore _sessionStore;
  final BiometricAuthenticator _biometrics;
  final PersonalDataWiper _wiper;

  void _emitIfOpen(AuthState next) {
    if (!isClosed) emit(next);
  }

  Future<void> logIn({required String mobileNumber, required String password}) async {
    emit(state.copyWith(status: AuthStatus.loading));
    final result = await _repository.logIn(mobileNumber: mobileNumber, password: password);
    await result.match(
      (failure) async =>
          _emitIfOpen(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (user) => _onSignedIn(user, fresh: true),
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

  /// [reason] is the (localised) text shown in the system biometric prompt.
  Future<void> logInWithBiometrics({required String reason}) async {
    final credential = await _sessionStore.loadBiometricCredential();
    if (credential == null) {
      // Never reachable from the UI (the button is hidden) — guards against
      // a stale button after data was wiped.
      _emitIfOpen(state.copyWith(status: AuthStatus.failure, biometricsReady: false, biometricIssue: BiometricIssue.unavailable));
      return;
    }
    emit(state.copyWith(status: AuthStatus.loading));
    final outcome = await _biometrics.authenticate(reason: reason);
    if (outcome != BiometricResult.success) {
      _emitIfOpen(state.copyWith(status: AuthStatus.failure, biometricIssue: _issueFor(outcome)));
      return;
    }
    final result = await _repository.logInWithStoredCredential(credential);
    await result.match(
      (failure) async =>
          _emitIfOpen(state.copyWith(status: AuthStatus.failure, errorMessage: failure.message)),
      (user) => _onSignedIn(user, fresh: false),
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

  /// Registers a user directly as logged in — used after the registration
  /// form completes, so a new customer isn't asked to log in again with
  /// the details they just entered.
  Future<void> registered(User user) => _onSignedIn(user, fresh: true);

  Future<void> _onSignedIn(User user, {required bool fresh}) async {
    await _sessionStore.saveUser(user);
    await _sessionStore.saveBiometricCredential(user.id);
    _emitIfOpen(state.copyWith(status: AuthStatus.success, user: user, freshSignIn: fresh));
  }

  /// Logout: clears session + registration details + free-WiFi grant.
  Future<void> logOut() async {
    // Emit first so route guards react immediately; storage wipe follows.
    emit(AuthState(biometricsReady: state.biometricsReady));
    await _sessionStore.endSession();
    await _wiper.wipeOnLogout();
    await refreshBiometrics();
  }

  /// After a confirmed account deletion: leaves no personal data behind,
  /// including the biometric credential, so biometrics are no longer offered.
  Future<void> signOutAndWipeEverything() async {
    emit(const AuthState());
    await _sessionStore.clearAll();
    await _wiper.wipeEverything();
  }
}
