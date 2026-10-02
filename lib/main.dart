// Entry point — build/maintained by W. Klopper, Research & Innovation.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/boot/boot_host.dart';
import 'package:sentech_connect_app/app/boot/boot_video_config.dart';
import 'package:sentech_connect_app/app/boot/boot_video_controller.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/session_restore.dart';
import 'package:sentech_connect_app/app/startup_error_app.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/diagnostics/error_handling.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/core/local/install_marker.dart';

void main() {
  // To send crashes to Sentry/Crashlytics, construct that reporter here
  // instead (see the docs on CrashReporter). Everything it receives has
  // already been scrubbed of personal data.
  final crashReporter = ConsoleCrashReporter();
  runGuarded(crashReporter, () => _start(crashReporter));
}

Future<void> _start(CrashReporter crashReporter) async {
  // Must run in the same zone as runApp (hence inside runGuarded).
  WidgetsFlutterBinding.ensureInitialized();
  // Explicit edge-to-edge: content draws behind the system status/nav
  // bars, with our own SafeArea usage controlling what sits clear of them,
  // rather than leaving it to each Android version's differing defaults.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // An invalid APP_FLAVOR / API_BASE_URL (e.g. http:// to a remote host) must
  // not start the app, and must not leave a blank screen either: report it
  // (the message never contains the raw defines) and show a minimal error.
  try {
    setupLocator(crashReporter: crashReporter, environment: AppEnvironment.fromDefines());
  } on InvalidEnvironment catch (error, stack) {
    await crashReporter.recordError(error, stack, fatal: true, reason: 'invalid build configuration');
    runApp(buildStartupErrorApp());
    return;
  }

  // Boot video (cold start only: main() is not re-run on resume). Start-up
  // work runs in parallel with it; the video never delays that work.
  runApp(BootHost(
    app: _prepareApp(),
    controllerFactory: bootVideoEnabled ? createAssetBootVideoController : null,
    onError: (error, stack) => unawaited(
      crashReporter.recordError(error, stack, fatal: true, reason: 'startup failed'),
    ),
  ));
}

Future<Widget> _prepareApp() async {
  final savedThemeMode = await AppPreferences.loadThemeMode();
  final savedLocale = await AppPreferences.loadLocale();
  final initialAuthState = await restoreAuthState(
    sessionStore: locator(),
    auth: locator(),
    biometrics: locator(),
    wiper: locator(),
    secureStore: locator(),
    installMarker: SharedPrefsInstallMarker(),
  );

  return SentechConnectApp(
    initialThemeMode: savedThemeMode,
    initialLocale: savedLocale,
    initialAuthState: initialAuthState,
    quickSplash: bootVideoEnabled,
  );
}
