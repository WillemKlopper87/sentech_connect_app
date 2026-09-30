import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

/// Composition-root implementation of [PersonalDataWiper]: fans a wipe out
/// to every feature that keeps personal data on the device. Session tokens
/// are handled by `SessionStore` (called by `AuthCubit`); the cart is
/// cleared by the app root when the auth state flips to signed-out.
class DefaultPersonalDataWiper implements PersonalDataWiper {
  DefaultPersonalDataWiper({required this._registration, required this._checkout, required this._freeWifi, required this._consent});

  final RegistrationRepository _registration;
  final CheckoutRepository _checkout;
  final FreeWifiRepository _freeWifi;
  final ConsentRepository _consent;

  @override
  Future<void> wipeOnLogout() async {
    await _registration.clear();
    await _checkout.clearLocalOrders();
    // Drops the active grant but keeps the daily ad counter, so logging out
    // and back in cannot be used to reset the free-WiFi cap.
    await _freeWifi.reset();
  }

  @override
  Future<void> wipeEverything() async {
    await wipeOnLogout();
    await _freeWifi.reset(includeDailyCounter: true);
    // Consent records are kept on logout (they hold no personal data beyond
    // purpose/version/time and avoid re-prompting), but go on account deletion.
    await _consent.clear();
  }
}
