import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/default_personal_data_wiper.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/auth/data/repositories/local_registration_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/privacy/data/repositories/local_consent_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';

class _FailingRegistration extends LocalRegistrationRepository {
  _FailingRegistration(super.store);

  @override
  Future<void> clear() async => throw StateError('registration store unavailable');
}

class _CountingCheckout extends MockCheckoutRepository {
  _CountingCheckout(super.store);

  int clears = 0;

  @override
  Future<void> clearLocalOrders() async => clears++;
}

class _CountingFreeWifi extends MockFreeWifiRepository {
  _CountingFreeWifi(super.store);

  final resets = <bool>[];

  @override
  Future<void> reset({bool includeDailyCounter = false}) async => resets.add(includeDailyCounter);
}

class _CountingConsent extends LocalConsentRepository {
  _CountingConsent(super.store);

  int clears = 0;

  @override
  Future<void> clear() async => clears++;
}

void main() {
  late InMemorySecureStore store;
  late _CountingCheckout checkout;
  late _CountingFreeWifi wifi;
  late _CountingConsent consent;
  late DefaultPersonalDataWiper wiper;

  setUp(() {
    store = InMemorySecureStore();
    checkout = _CountingCheckout(store);
    wifi = _CountingFreeWifi(store);
    consent = _CountingConsent(store);
    wiper = DefaultPersonalDataWiper(
      registration: _FailingRegistration(store),
      checkout: checkout,
      freeWifi: wifi,
      consent: consent,
    );
  });

  test('one failing store does not stop the others from being wiped on logout; the error is reported at the end', () async {
    await expectLater(wiper.wipeOnLogout(), throwsStateError);
    expect(checkout.clears, 1);
    expect(wifi.resets, [false]);
    expect(consent.clears, 0, reason: 'consent is kept on logout');
  });

  test('account deletion still wipes everything else when one step fails', () async {
    await expectLater(wiper.wipeEverything(), throwsStateError);
    expect(checkout.clears, 1);
    expect(wifi.resets, [false, true]);
    expect(consent.clears, 1);
  });
}
