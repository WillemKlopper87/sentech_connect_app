/// Removes personal data held on the device. Implemented in the composition
/// root (`lib/app/default_personal_data_wiper.dart`) because it has to reach
/// across features (session, registration, consent, free-WiFi state).
abstract class PersonalDataWiper {
  /// Logout: session, registration details and any active free-WiFi grant.
  /// Keeps the opaque biometric credential and the consent record.
  Future<void> wipeOnLogout();

  /// Account deletion: everything above plus the biometric credential and
  /// consent record — the device holds nothing about the customer afterwards.
  Future<void> wipeEverything();
}
