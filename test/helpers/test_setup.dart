import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/biometrics/biometric_authenticator.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/connectivity_service.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/shared/widgets/osm_map.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

/// 1x1 transparent PNG, so map tiles render without any network access.
final Uint8List _transparentPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNkYPhfDwAChwGA60e6kgAAAABJRU5ErkJggg==',
);

class _OfflineTileProvider extends TileProvider {
  @override
  ImageProvider getImage(TileCoordinates coordinates, TileLayer options) =>
      MemoryImage(_transparentPng);
}

/// Calls received on the app's platform channel (e.g. FLAG_SECURE toggles).
final List<MethodCall> platformCalls = [];

/// Replaces platform-backed services (Keystore, biometric prompt, ...) with
/// in-memory fakes. Call right after `setupLocator()`; returns nothing —
/// fetch the fakes back out of `locator` when a test needs to script them.
void registerTestFakes() {
  locator.allowReassignment = true;
  locator.registerLazySingleton<SecureStore>(() => InMemorySecureStore());
  locator.registerLazySingleton<PlatformClock>(() => FakePlatformClock());
  locator.registerLazySingleton<ConnectivityService>(() => FakeConnectivityService());
  locator.registerLazySingleton<NotificationService>(() => FakeNotificationService());
  locator.registerLazySingleton<BiometricAuthenticator>(() => MockBiometricAuthenticator());
  locator.registerLazySingleton<TenantPreferences>(() => InMemoryTenantPreferences());
}

/// Shared setup for widget tests that boot the full app: fresh DI container,
/// empty SharedPreferences, and an offline map tile provider. Call once from
/// `main()` of a test file.
void setUpAppTests() {
  setUpAll(() {
    OsmMap.tileProviderOverride = _OfflineTileProvider();
  });

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    platformCalls.clear();
    ScreenSecurity.resetForTest();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenSecurity.channel, (call) async {
      platformCalls.add(call);
      return null;
    });
    SharedPreferences.setMockInitialValues({});
    await locator.reset();
    setupLocator();
    registerTestFakes();
  });

  tearDownAll(() {
    OsmMap.tileProviderOverride = null;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(ScreenSecurity.channel, null);
  });
}
