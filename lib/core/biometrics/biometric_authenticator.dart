enum BiometricAvailability {
  /// Hardware present and at least one biometric enrolled.
  available,

  /// Hardware present but nothing enrolled — send the user to system settings.
  notEnrolled,

  /// No hardware, or not usable right now.
  unavailable,
}

enum BiometricResult {
  success,

  /// User dismissed the prompt or chose the fallback — not an error.
  cancelled,
  notEnrolled,
  unavailable,

  /// Too many failed attempts; retry after a short wait.
  lockedOut,

  /// Biometrics disabled until the user unlocks the device with their PIN.
  permanentlyLockedOut,
  failed,
}

/// Domain seam over the platform biometric prompt so the auth flow can be
/// tested (and the mechanism replaced) without touching the UI or cubits.
abstract class BiometricAuthenticator {
  Future<BiometricAvailability> availability();

  /// Shows the system biometric prompt. Never falls back to device PIN — the
  /// app's own password login is the fallback.
  Future<BiometricResult> authenticate({required String reason});
}

/// Scriptable implementation for tests and demos.
class MockBiometricAuthenticator implements BiometricAuthenticator {
  MockBiometricAuthenticator({
    this.nextAvailability = BiometricAvailability.available,
    this.nextResult = BiometricResult.success,
  });

  BiometricAvailability nextAvailability;
  BiometricResult nextResult;
  int authenticateCalls = 0;

  @override
  Future<BiometricAvailability> availability() async => nextAvailability;

  @override
  Future<BiometricResult> authenticate({required String reason}) async {
    authenticateCalls++;
    return nextResult;
  }
}
