import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/auth/domain/entities/user.dart';

/// Which tenant and which customer the stored session record belongs to.
/// Compared with the active tenant and the API tokens to catch a session
/// that does not belong to what the app is now serving.
class SessionBinding extends Equatable {
  const SessionBinding({required this.tenantSlug, required this.customerId});

  final String tenantSlug;
  final String customerId;

  @override
  List<Object?> get props => [tenantSlug, customerId];
}

/// The signed-in customer's record on this device (secure storage). The API
/// tokens live in `TokenStore`; this holds the [User] shown in the app, the
/// tenant/customer it is bound to, and the biometric marker.
abstract class SessionStore {
  Future<User?> loadUser();

  /// Stores [user] bound to [tenantSlug] (and to the customer id, `user.id`).
  Future<void> saveUser(User user, {required String tenantSlug});

  /// The tenant/customer the stored record is bound to; null when there is no
  /// record, or it predates bindings (mock-phase builds), which callers treat
  /// as a session they cannot trust.
  Future<SessionBinding?> loadBinding();

  /// Marker (the customer id) that a session was established on this device:
  /// it is what makes "Use biometrics" appear. Only ever written after a
  /// successful sign-in, so biometrics can never be the *first* way into a
  /// device; biometrics unlock the stored session, they never replace it.
  Future<String?> loadBiometricCredential();

  Future<void> saveBiometricCredential(String credential);

  /// Logout and account deletion: removes the session record and the
  /// biometric marker (the next sign-in is interactive).
  Future<void> clearAll();
}
