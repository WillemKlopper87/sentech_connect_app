import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';

/// Routes every uncaught error to [reporter] (scrubbed of personal data):
///  * `FlutterError.onError`            - errors thrown inside the framework
///    (build/layout/paint, gesture callbacks);
///  * `PlatformDispatcher.instance.onError` - uncaught async errors that reach
///    the root isolate;
///  * [runGuarded]                      - errors escaping the app's own zone.
/// In debug builds framework errors are still printed in full, as usual.
void installErrorHandlers(CrashReporter reporter) {
  FlutterError.onError = (details) {
    reporter.recordError(details.exception, details.stack, reason: details.context?.toDescription());
    if (kDebugMode) FlutterError.presentError(details);
  };
  PlatformDispatcher.instance.onError = (error, stack) {
    reporter.recordError(error, stack, fatal: true);
    return true; // handled: don't let the platform terminate the isolate's error zone
  };
}

/// Runs [body] (which should call `runApp`) inside a guarded zone with the
/// global handlers installed.
Future<void> runGuarded(CrashReporter reporter, Future<void> Function() body) async {
  await runZonedGuarded(
    () async {
      installErrorHandlers(reporter);
      await body();
    },
    (error, stack) => reporter.recordError(error, stack, fatal: true),
  );
}
