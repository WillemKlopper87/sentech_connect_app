import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

/// Where the signed-in session lives on this device. The real backend phase
/// replaces the stored [User] with OIDC tokens (refresh token in secure
/// storage) — callers only ever see this interface.
abstract class SessionStore {
  Future<User?> loadUser();

  Future<void> saveUser(User user);

  /// Opaque reference (user id today, a refresh token once a backend exists)
  /// that lets the biometric prompt re-establish a session after an explicit
  /// logout. Only ever written after a successful password login or
  /// registration, so biometrics can never be the *first* way into a device.
  Future<String?> loadBiometricCredential();

  Future<void> saveBiometricCredential(String credential);

  /// Logout: removes the active session but keeps the biometric credential
  /// so the customer can get back in with a fingerprint/face.
  Future<void> endSession();

  /// Account deletion / full wipe: removes the session and the credential.
  Future<void> clearAll();
}
