// ignore_for_file: prefer_initializing_formals

import 'package:sentech_connect_app/core/local/personal_data_wiper.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/pass_local_store.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/registration_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/privacy/domain/repositories/consent_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

/// Composition-root implementation of [PersonalDataWiper]: fans a wipe out
/// to every feature that keeps personal data on the device. Session tokens
/// are handled by `SessionStore` (called by `AuthCubit`); the cart is
/// cleared by the app root when the auth state flips to signed-out.
class DefaultPersonalDataWiper implements PersonalDataWiper {
  DefaultPersonalDataWiper({
    required this._registration,
    required this._checkout,
    required this._freeWifi,
    required this._consent,
    PassLocalStore? passes,
  }) : _passes = passes;

  final RegistrationRepository _registration;
  final CheckoutRepository _checkout;
  final FreeWifiRepository _freeWifi;
  final ConsentRepository _consent;
  final PassLocalStore? _passes;

  @override
  Future<void> wipeOnLogout() => _runAll([
    _registration.clear,
    _checkout.clearLocalOrders,
    if (_passes case final passes?) passes.clearPersonalData,
    // Drops the active grant but keeps the daily ad counter, so logging
    // out and back in cannot be used to reset the free-WiFi cap.
    () => _freeWifi.reset(),
  ]);

  @override
  Future<void> wipeEverything() => _runAll([
    wipeOnLogout,
    () => _freeWifi.reset(includeDailyCounter: true),
    // Consent records are kept on logout (they hold no personal data
    // beyond purpose/version/time and avoid re-prompting), but go on
    // account deletion.
    _consent.clear,
  ]);

  /// Every step runs even if an earlier one throws (one failing store must
  /// not leave the others' personal data behind); the first error is
  /// rethrown at the end.
  static Future<void> _runAll(List<Future<void> Function()> steps) async {
    Object? firstError;
    StackTrace? firstStack;
    for (final step in steps) {
      try {
        await step();
      } catch (error, stack) {
        firstError ??= error;
        firstStack ??= stack;
      }
    }
    if (firstError != null) Error.throwWithStackTrace(firstError, firstStack!);
  }
}
