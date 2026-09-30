import 'package:flutter/foundation.dart';
import 'package:sentech_connect_app/core/diagnostics/pii_scrubber.dart';

/// An error already stripped of personal data. Reporters only ever receive
/// this, so no implementation can forget to scrub.
class CrashReport {
  const CrashReport({required this.message, required this.stackTrace, required this.fatal, this.reason});

  factory CrashReport.from(Object error, StackTrace? stack, {required bool fatal, String? reason}) {
    return CrashReport(
      message: PiiScrubber.scrub('${error.runtimeType}: $error'),
      stackTrace: PiiScrubber.scrub((stack ?? StackTrace.empty).toString()),
      fatal: fatal,
      reason: reason == null ? null : PiiScrubber.scrub(reason),
    );
  }

  final String message;
  final String stackTrace;
  final bool fatal;
  final String? reason;
}

/// Where scrubbed crash reports go.
///
/// ## Plugging in Sentry
/// `flutter pub add sentry_flutter`, then implement:
/// ```dart
/// class SentryCrashReporter implements CrashReporter {
///   Future<void> report(CrashReport r) => Sentry.captureMessage(
///       r.message, level: r.fatal ? SentryLevel.fatal : SentryLevel.error,
///       withScope: (s) => s.setContexts('report', {'stack': r.stackTrace, 'reason': r.reason}));
/// }
/// ```
/// Initialise with `SentryFlutter.init((o) { o.dsn = const String.fromEnvironment('SENTRY_DSN');
/// o.sendDefaultPii = false; o.beforeSend = (e, _) => e; })` and wrap `runApp` as shown in
/// `main.dart`. Keep `sendDefaultPii` off and do not attach user ids/emails.
///
/// ## Plugging in Firebase Crashlytics
/// After the Firebase project exists (see `NotificationService` docs), implement
/// `report` as `FirebaseCrashlytics.instance.recordError(r.message, StackTrace.fromString(r.stackTrace),
/// reason: r.reason, fatal: r.fatal)`; call `setCrashlyticsCollectionEnabled(false)` until the
/// customer's analytics/diagnostics consent allows it. Register the new reporter in
/// `lib/app/locator.dart`; nothing else changes.
abstract class CrashReporter {
  /// Delivers a scrubbed report. Must never throw.
  Future<void> report(CrashReport report);

  /// Convenience used by the global handlers and by feature code.
  Future<void> recordError(Object error, StackTrace? stack, {bool fatal = false, String? reason}) async {
    try {
      await report(CrashReport.from(error, stack, fatal: fatal, reason: reason));
    } catch (_) {
      // Reporting must never crash the app.
    }
  }
}

/// Development reporter: prints the scrubbed report to the console.
class ConsoleCrashReporter extends CrashReporter {
  @override
  Future<void> report(CrashReport r) async {
    debugPrint('[${r.fatal ? 'FATAL' : 'ERROR'}] ${r.message}${r.reason == null ? '' : ' (${r.reason})'}');
    if (r.stackTrace.isNotEmpty) debugPrint(r.stackTrace);
  }
}
