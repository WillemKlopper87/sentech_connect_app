// Entry point — build/maintained by W. Klopper, Research & Innovation.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/app/startup_error_app.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/diagnostics/error_handling.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/features/auth/domain/repositories/session_store.dart';
import 'package:sentech_connect_app/features/auth/presentation/bloc/auth_cubit.dart';

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

  final savedThemeMode = await AppPreferences.loadThemeMode();
  final savedLocale = await AppPreferences.loadLocale();
  final savedUser = await locator<SessionStore>().loadUser();

  runApp(SentechConnectApp(
    initialThemeMode: savedThemeMode,
    initialLocale: savedLocale,
    initialAuthState: savedUser == null
        ? const AuthState()
        : AuthState(status: AuthStatus.success, user: savedUser),
  ));
}
