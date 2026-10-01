/// Removes personal data held on the device. Implemented in the composition
/// root (`lib/app/default_personal_data_wiper.dart`) because it has to reach
/// across features (session, registration, consent, free-WiFi state).
abstract class PersonalDataWiper {
  /// Logout: registration details, local orders and any active free-WiFi
  /// grant. Keeps the consent record. (The session and the biometric
  /// credential are forgotten by `AuthCubit` through `SessionStore`.)
  /// Every step runs even if one fails; the first error is rethrown.
  Future<void> wipeOnLogout();

  /// Account deletion: everything above plus the consent record and the free-
  /// WiFi daily counter; with `AuthCubit`'s session wipe the device holds
  /// nothing about the customer afterwards.
  Future<void> wipeEverything();
}
