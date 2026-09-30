import 'dart:async';

import 'package:permission_handler/permission_handler.dart';

enum NotificationPermissionStatus {
  granted,

  /// Not granted yet; the system prompt can still be shown.
  denied,

  /// The user blocked it (or declined twice on Android 13+); only system
  /// settings can change that.
  permanentlyDenied,
}

class PushMessage {
  const PushMessage({required this.title, required this.body, this.data = const {}});

  final String title;
  final String body;
  final Map<String, String> data;
}

/// Push notifications behind an interface. Today's implementation only
/// handles the Android 13+ `POST_NOTIFICATIONS` permission flow; there is no
/// push transport because FCM needs a Firebase project this repo does not
/// have.
///
/// ## Wiring Firebase Cloud Messaging once the owner supplies config
///
/// 1. Owner creates a Firebase project and registers the Android app with the
///    FINAL applicationId (see `sentech.applicationId` in android/gradle.properties),
///    adds the release + debug SHA-256 fingerprints, and downloads
///    `google-services.json` into `android/app/` (do not commit it if the repo
///    is public; it holds no secrets but is environment-specific). iOS: upload
///    an APNs key (Apple team id required) and add `GoogleService-Info.plist`.
/// 2. `flutter pub add firebase_core firebase_messaging` and run
///    `dart pub global activate flutterfire_cli && flutterfire configure`
///    (generates `lib/firebase_options.dart`).
/// 3. android/settings.gradle.kts: add plugin
///    `id("com.google.gms.google-services") version "<latest>" apply false`;
///    android/app/build.gradle.kts: add `id("com.google.gms.google-services")`
///    to `plugins`.
/// 4. In `main()`: `await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);`
///    and register `FirebaseNotificationService` (below) in `lib/app/locator.dart`
///    instead of [PermissionNotificationService].
/// 5. Implement `FirebaseNotificationService implements NotificationService`:
///    `requestPermission` -> `FirebaseMessaging.instance.requestPermission()`;
///    `getPushToken` -> `FirebaseMessaging.instance.getToken()`; `onMessage` ->
///    `FirebaseMessaging.onMessage.map(...)`; register
///    `FirebaseMessaging.onBackgroundMessage` with a top-level handler.
/// 6. Send the token to the backend after login (and on `onTokenRefresh`) and
///    delete it on logout/account deletion. Define notification channels
///    (usage thresholds, outage, order status) and honour the marketing-push
///    consent captured at registration.
abstract class NotificationService {
  Future<NotificationPermissionStatus> permissionStatus();

  /// Shows the system permission prompt (no-op result on Android < 13, where
  /// notifications are allowed by default).
  Future<NotificationPermissionStatus> requestPermission();

  /// Opens the app's system settings page (for [NotificationPermissionStatus.permanentlyDenied]).
  Future<void> openSystemSettings();

  /// Push token for the backend; null until a push transport (FCM) is wired.
  Future<String?> getPushToken();

  /// Foreground push messages; empty until a push transport is wired.
  Stream<PushMessage> get onMessage;
}

/// Permission-only implementation backed by `permission_handler`.
class PermissionNotificationService implements NotificationService {
  NotificationPermissionStatus _map(PermissionStatus status) {
    if (status.isGranted || status.isLimited || status.isProvisional) return NotificationPermissionStatus.granted;
    if (status.isPermanentlyDenied) return NotificationPermissionStatus.permanentlyDenied;
    return NotificationPermissionStatus.denied;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    try {
      return _map(await Permission.notification.status);
    } catch (_) {
      return NotificationPermissionStatus.denied;
    }
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    try {
      return _map(await Permission.notification.request());
    } catch (_) {
      return NotificationPermissionStatus.denied;
    }
  }

  @override
  Future<void> openSystemSettings() async {
    await openAppSettings();
  }

  @override
  Future<String?> getPushToken() async => null;

  @override
  Stream<PushMessage> get onMessage => const Stream.empty();
}

/// Scriptable implementation for tests.
class FakeNotificationService implements NotificationService {
  FakeNotificationService({this.status = NotificationPermissionStatus.denied, this.statusAfterRequest});

  NotificationPermissionStatus status;

  /// What the system prompt resolves to; defaults to granting.
  NotificationPermissionStatus? statusAfterRequest;
  int requestCalls = 0;
  int settingsOpened = 0;

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => status;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestCalls++;
    status = statusAfterRequest ?? NotificationPermissionStatus.granted;
    return status;
  }

  @override
  Future<void> openSystemSettings() async => settingsOpened++;

  @override
  Future<String?> getPushToken() async => null;

  @override
  Stream<PushMessage> get onMessage => const Stream.empty();
}
