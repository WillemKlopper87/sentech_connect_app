import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/install_marker.dart';
import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/auth_repository.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

/// The launch auth state from what is stored on the device. Anything that
/// cannot be trusted is discarded (and local personal data wiped) instead of
/// being resumed:
///  - no install marker: secure storage (Keychain) outlived an uninstall, so
///    whatever it holds belongs to a previous installation;
///  - a stored user without a tenant/customer binding (mock-phase builds), or
///    without API tokens for that same customer and tenant (a "zombie" that
///    the server would reject on every call);
///  - any storage error while checking (fail closed: start signed out).
/// Whether the session also matches the tenant the app opens with is checked
/// once that tenant is active (`AuthCubit.ensureSessionMatches`).
Future<AuthState> restoreAuthState({
  required SessionStore sessionStore,
  required AuthRepository auth,
  required BiometricAuthenticator biometrics,
  required PersonalDataWiper wiper,
  required SecureStore secureStore,
  required InstallMarker installMarker,
}) async {
  Future<void> discardEverything() async {
    for (final step in [sessionStore.clearAll, auth.discardLocalSession, wiper.wipeOnLogout]) {
      try {
        await step();
      } catch (_) {
        // Keep forgetting the rest; the result below is signed out anyway.
      }
    }
  }

  try {
    if (!await installMarker.exists()) {
      final held = await sessionStore.loadUser() != null || await sessionStore.loadBiometricCredential() != null;
      await secureStore.deleteAll();
      await auth.discardLocalSession();
      if (held) await wiper.wipeOnLogout();
      await installMarker.create();
    }

    final user = await sessionStore.loadUser();
    if (user == null) return const AuthState();
    final binding = await sessionStore.loadBinding();
    final trusted = binding != null &&
        binding.customerId == user.id &&
        await auth.sessionMatches(tenantSlug: binding.tenantSlug, user: user);
    if (!trusted) {
      await discardEverything();
      return const AuthState();
    }

    final credential = await sessionStore.loadBiometricCredential();
    return AuthState.restore(
      user: user,
      hasBiometricCredential: credential != null,
      biometricsAvailable: credential != null && await _biometricsAvailable(biometrics),
    );
  } catch (_) {
    return const AuthState();
  }
}

/// A plugin failure counts as "no usable biometrics" (the real authenticator
/// already maps its own errors to `unavailable`). Accepted behaviour: without
/// usable biometrics the stored session opens without the lock screen; the
/// biometric lock is a convenience on top of Keystore/Keychain + device lock,
/// not the session's only protection.
Future<bool> _biometricsAvailable(BiometricAuthenticator biometrics) async {
  try {
    return await biometrics.availability() == BiometricAvailability.available;
  } catch (_) {
    return false;
  }
}
