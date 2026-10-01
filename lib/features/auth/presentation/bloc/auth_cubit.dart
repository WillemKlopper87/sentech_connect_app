import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/otp_challenge.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/privacy/domain/entities/consent_record.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';

/// [locked]: a session is stored on this device but waits for a biometric
/// unlock (cold start with an enrolled biometric). Not signed in.
enum AuthStatus { initial, loading, success, failure, locked }

/// Why a biometric attempt did not sign the user in. The login page maps
/// these to (localised) guidance; [cancelled] is deliberately silent.
enum BiometricIssue { cancelled, notEnrolled, unavailable, lockedOut, permanentlyLockedOut, failed }

/// Whether the signed-in customer has accepted the CURRENT terms and privacy
/// notice. Anything but [accepted] keeps them on the consent step, however the
/// session began (OTP, biometric unlock, restored at launch).
enum LegalStatus {
  accepted,

  /// Not known yet (being checked).
  unchecked,

  /// Checked: the current versions have not been accepted.
  required,

  /// The check or the recording failed (offline, server): retry, never
  /// treated as a decline or as consent.
  unavailable,
}

class AuthState extends Equatable {
  const AuthState({
    this.status = AuthStatus.initial,
    this.user,
    this.errorMessage,
    this.biometricsReady = false,
    this.biometricIssue,
    this.freshSignIn = false,
    this.legal = LegalStatus.accepted,
    this.providerUnavailable = false,
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

  final LegalStatus legal;

  /// The session was ended because the provider is suspended; the login page
  /// says so once (cleared by any later state change).
  final bool providerUnavailable;

  bool get isSignedIn => status == AuthStatus.success && user != null;

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    String? errorMessage,
    bool? biometricsReady,
    BiometricIssue? biometricIssue,
    bool? freshSignIn,
    LegalStatus? legal,
  }) {
    return AuthState(
      status: status ?? this.status,
      user: user ?? this.user,
      errorMessage: errorMessage,
      biometricsReady: biometricsReady ?? this.biometricsReady,
      biometricIssue: biometricIssue,
      freshSignIn: freshSignIn ?? this.freshSignIn,
      legal: legal ?? this.legal,
      providerUnavailable: false,
    );
  }

  @override
  List<Object?> get props => [status, user, errorMessage, biometricsReady, biometricIssue, freshSignIn, legal, providerUnavailable];
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
    Stream<void>? providerUnavailable,
    String Function()? activeTenantSlug,
    ConsentRepository? consents,
  }) : _activeTenantSlug = activeTenantSlug ?? (() => TenantContext.defaultSlug),
       _consents = consents,
       super(consents != null && initial.isSignedIn ? initial.copyWith(legal: LegalStatus.unchecked) : initial) {
    _expiry = sessionExpired?.listen((_) => _onSessionExpired());
    _suspended = providerUnavailable?.listen((_) => _onProviderUnavailable());
  }

  final AuthRepository _repository;
  final SessionStore _sessionStore;
  final BiometricAuthenticator _biometrics;
  final PersonalDataWiper _wiper;
  final String Function() _activeTenantSlug;
  final ConsentRepository? _consents;
  StreamSubscription<void>? _expiry;
  StreamSubscription<void>? _suspended;

  /// Interactive sign-ins running (verify + sign-in). A session-expired event
  /// during one belongs to the session being REPLACED, never to the new one.
  int _signingIn = 0;

  void _emitIfOpen(AuthState next) {
    if (!isClosed) emit(next);
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
    // Signed out (or closed) while the session was being re-opened: do not
    // bring it back.
    if (isClosed || state.status != AuthStatus.loading) return;
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
      (user) async {
        // The session the server resumed must be the customer this device
        // holds: a different id means the tokens and the stored record (or
        // biometric marker) belong to different customers. Nothing of either
        // may be kept.
        final record = await _sessionStore.loadUser();
        if (user.id != credential || (record != null && record.id != user.id)) {
          await _rejectForeignSession();
          return;
        }
        await signedIn(user, fresh: false);
      },
    );
  }

  Future<void> _rejectForeignSession() async {
    _emitIfOpen(const AuthState());
    try {
      await _endSession(_wiper.wipeOnLogout);
    } catch (_) {
      // Signed out in the UI regardless; every step still ran.
    }
    _emitIfOpen(const AuthState(status: AuthStatus.failure, errorMessage: 'Your session could not be verified. Sign in again.'));
  }

  BiometricIssue _issueFor(BiometricResult result) => switch (result) {
        BiometricResult.cancelled => BiometricIssue.cancelled,
        BiometricResult.notEnrolled => BiometricIssue.notEnrolled,
        BiometricResult.unavailable => BiometricIssue.unavailable,
        BiometricResult.lockedOut => BiometricIssue.lockedOut,
        BiometricResult.permanentlyLockedOut => BiometricIssue.permanentlyLockedOut,
        _ => BiometricIssue.failed,
      };

  /// Verifies the SMS code AND signs the customer in, as one operation (the
  /// login UI never calls the repository and the cubit separately, so the
  /// tokens that verification stores can never be left without a session).
  /// The legal consent step is enforced afterwards by [AuthState.legal] (the
  /// router), for every way a session can begin. Session-expired events are
  /// ignored while this runs.
  Future<Either<Failure, User>> signInWithOtp({required OtpChallenge challenge, required String code}) async {
    _signingIn++;
    try {
      final verified = await _repository.verifyOtp(challenge: challenge, code: code);
      final user = verified.match((_) => null, (u) => u);
      if (user == null || isClosed) return verified;
      try {
        await signedIn(user, fresh: true);
      } catch (_) {
        await _discardNewSession();
        return const Left(SessionSetupFailure());
      }
      return Right(user);
    } finally {
      _signingIn--;
    }
  }

  /// A verified session that is not going to be used: revoke it (best effort,
  /// bounded) and make sure no token stays on the device.
  Future<void> _discardNewSession() async {
    try {
      await _repository.logOut().timeout(const Duration(seconds: 10));
    } catch (_) {
      // Fall through: the local tokens are dropped below regardless.
    }
    try {
      await _repository.discardLocalSession();
    } catch (_) {
      // Nothing more can be done from here.
    }
  }

  /// After an interactive sign-in ([fresh]) or a biometric unlock.
  ///
  /// Signing in as a DIFFERENT customer than the one stored on this device
  /// first wipes everything local that belonged to the previous one (orders,
  /// registration details, free-WiFi grant), before the new session is saved.
  /// When that wipe fails the new customer's tokens are dropped again (they
  /// must not sit next to the previous customer's data) and the error is
  /// rethrown.
  Future<void> signedIn(User user, {required bool fresh}) async {
    final previous = state.user ?? await _sessionStore.loadUser();
    if (previous != null && previous.id != user.id) {
      try {
        await _wiper.wipeOnLogout();
      } catch (_) {
        await _discardNewSession();
        rethrow;
      }
    }
    await _sessionStore.saveUser(user, tenantSlug: _activeTenantSlug());
    await _sessionStore.saveBiometricCredential(user.id);
    _emitIfOpen(state.copyWith(
      status: AuthStatus.success,
      user: user,
      freshSignIn: fresh,
      legal: _consents == null ? LegalStatus.accepted : LegalStatus.unchecked,
    ));
  }

  /// After the customer completed or edited their profile.
  /// [legalAccepted]: the profile step has just recorded the consents.
  Future<void> profileUpdated(User user, {bool legalAccepted = false}) async {
    await _sessionStore.saveUser(user, tenantSlug: _activeTenantSlug());
    _emitIfOpen(state.copyWith(
      status: AuthStatus.success,
      user: user,
      legal: legalAccepted ? LegalStatus.accepted : state.legal,
    ));
  }

  static const _legalPurposes = [ConsentPurpose.terms, ConsentPurpose.privacy];
  Future<void>? _legalCheck;

  /// Looks up whether the CURRENT terms and privacy notice are accepted and
  /// sets [AuthState.legal]. A lookup that fails is `unavailable` (retry),
  /// never "not accepted": someone who already agreed is not asked again
  /// because of a bad connection. Concurrent calls share one check.
  Future<void> checkLegal() => _legalCheck ??= _runLegalCheck().whenComplete(() {
        _legalCheck = null;
      });

  Future<void> _runLegalCheck() async {
    final user = state.user;
    if (!state.isSignedIn || isClosed) return;
    final consents = _consents;
    if (consents == null) {
      _emitIfOpen(state.copyWith(legal: LegalStatus.accepted));
      return;
    }
    if (state.legal != LegalStatus.unchecked) _emitIfOpen(state.copyWith(legal: LegalStatus.unchecked));
    var unknown = false;
    var missing = false;
    try {
      for (final purpose in _legalPurposes) {
        final result = await consents.currentConsent(purpose);
        result.match((_) => unknown = true, (record) => missing = missing || record == null);
      }
    } catch (_) {
      unknown = true;
    }
    if (!_sameSignedInUser(user)) return;
    _emitIfOpen(state.copyWith(
      legal: unknown
          ? LegalStatus.unavailable
          : missing
              ? LegalStatus.required
              : LegalStatus.accepted,
    ));
  }

  /// The customer agrees to the CURRENT terms and privacy notice on the
  /// consent step (recorded in the ledger; a repeat is a no-op).
  Future<void> acceptLegal() => _legalAccept ??= _runAcceptLegal().whenComplete(() {
        _legalAccept = null;
      });

  Future<void>? _legalAccept;

  Future<void> _runAcceptLegal() async {
    final user = state.user;
    final consents = _consents;
    if (!state.isSignedIn || consents == null) return;
    var failed = false;
    try {
      for (final purpose in _legalPurposes) {
        final granted = await consents.grant(purpose);
        if (granted.isLeft()) {
          failed = true;
          break;
        }
      }
    } catch (_) {
      failed = true;
    }
    if (!_sameSignedInUser(user)) return;
    _emitIfOpen(state.copyWith(legal: failed ? LegalStatus.unavailable : LegalStatus.accepted));
  }

  bool _sameSignedInUser(User? user) => !isClosed && state.isSignedIn && state.user?.id == user?.id;

  /// Signs out (full wipe) when the session held on this device does not
  /// belong to what the app is serving: no API tokens, tokens for another
  /// tenant or customer, or a stored record without a matching binding (a
  /// mock-phase build, a keychain that outlived a reinstall, a tenant chosen
  /// afresh). Called after every tenant activation and at launch, so a
  /// customer is never shown another tenant's or customer's data with a
  /// session that the server would reject on every call.
  Future<void> ensureSessionMatches(String activeSlug) async {
    final user = state.user;
    if (user == null || isClosed) return;
    final binding = await _sessionStore.loadBinding();
    final matches = binding != null &&
        binding.tenantSlug == activeSlug &&
        binding.customerId == user.id &&
        await _repository.sessionMatches(tenantSlug: activeSlug, user: user);
    if (!matches && !isClosed && state.user != null) await logOut();
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
    if (_signingIn > 0) return; // belongs to the session being replaced
    if (!state.isSignedIn && state.status != AuthStatus.locked) return;
    try {
      await logOut();
    } catch (_) {
      // Already signed out in the UI; a storage failure here has no caller
      // to report to (and must not become an unhandled async error).
    }
  }

  /// 403 `tenant_suspended`: sign out like an expired session, then leave a
  /// notice for the login page.
  Future<void> _onProviderUnavailable() async {
    if (_signingIn > 0) return;
    if (!state.isSignedIn && state.status != AuthStatus.locked) return;
    try {
      await logOut();
    } catch (_) {
      // Already signed out in the UI; see _onSessionExpired.
    }
    _emitIfOpen(const AuthState(providerUnavailable: true));
  }

  @override
  Future<void> close() async {
    await _suspended?.cancel();
    await _expiry?.cancel();
    return super.close();
  }
}
