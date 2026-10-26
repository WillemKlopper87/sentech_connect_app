import 'dart:ui';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/diagnostics/error_handling.dart';
import 'package:sentech_connect_app/core/diagnostics/pii_scrubber.dart';

class _RecordingReporter extends CrashReporter {
  final reports = <CrashReport>[];

  @override
  Future<void> report(CrashReport r) async => reports.add(r);
}

class _ThrowingReporter extends CrashReporter {
  @override
  Future<void> report(CrashReport r) async => throw StateError('backend down');
}

void main() {
  group('PiiScrubber', () {
    final cases = <String, String>{
      'failed for lindiwe.khumalo@example.co.za': 'failed for [email]',
      'mobile 081 000 0000 rejected': 'mobile [phone] rejected',
      'mobile 0810000000 rejected': 'mobile [phone] rejected',
      'call +27 81 000 0000': 'call [phone]',
      'id 9001015800087 invalid': 'id [number] invalid',
      'voucher SEN-4XJ2-9KLM not found': 'voucher [voucher] not found',
      'at -26.205871, 28.049722': 'at [coord], [coord]',
      'Authorization: Bearer abc.def-123_xyz': 'Authorization: Bearer [token]',
      'key=AbCdEfGhIjKlMnOpQrStUvWxYz0123456789': 'key=[token]',
    };
    cases.forEach((input, expected) {
      test('"$input"', () => expect(PiiScrubber.scrub(input), expected));
    });

    test('removes the sign-in binding, one-time code and human-check token whatever their shape', () {
      const binding = 'Zm9vYmFyYmF6cXV4MTIzNDU2Nzg5MEFCQ0RFRkc';
      expect(
        PiiScrubber.scrub('{"binding":"$binding","code":"123456","turnstile_token":"0.abc"}'),
        '{"binding":"[redacted]","code":"[redacted]","turnstile_token":"[redacted]"}',
      );
      expect(PiiScrubber.scrub('binding=$binding&code=123456'), 'binding=[redacted]&code=[redacted]');
      expect(PiiScrubber.scrub('verify failed code: 123456'), 'verify failed code: [redacted]');
    });

    test('leaves ordinary diagnostics alone', () {
      const text =
          'RenderFlex overflowed by 12 pixels on the right (lib/features/cart/cart_page.dart:42)';
      expect(PiiScrubber.scrub(text), text);
    });
  });

  group('CrashReport', () {
    test(
      'is scrubbed before any reporter sees it (message, stack and reason)',
      () async {
        final reporter = _RecordingReporter();
        await reporter.recordError(
          Exception('could not save 0810000000 for jo@example.com'),
          StackTrace.fromString(
            '#0 save (package:app/x.dart:1) user=jo@example.com',
          ),
          reason: 'registration for 9001015800087',
        );
        final r = reporter.reports.single;
        expect(r.message, isNot(contains('0810000000')));
        expect(r.message, isNot(contains('@example.com')));
        expect(r.stackTrace, isNot(contains('@example.com')));
        expect(r.reason, isNot(contains('9001015800087')));
      },
    );

    test('a failing reporter never throws into the app', () async {
      await _ThrowingReporter().recordError(StateError('x'), null);
    });
  });

  group('global error handlers', () {
    late FlutterExceptionHandler? originalFlutterOnError;
    late ErrorCallback? originalPlatformOnError;

    setUp(() {
      originalFlutterOnError = FlutterError.onError;
      originalPlatformOnError = PlatformDispatcher.instance.onError;
    });

    tearDown(() {
      FlutterError.onError = originalFlutterOnError;
      PlatformDispatcher.instance.onError = originalPlatformOnError;
    });

    test('FlutterError.onError reports framework errors, scrubbed', () async {
      final reporter = _RecordingReporter();
      installErrorHandlers(reporter);
      final originalPresentError = FlutterError.presentError;
      final presented = <FlutterErrorDetails>[];
      FlutterError.presentError = presented.add;
      addTearDown(() => FlutterError.presentError = originalPresentError);

      FlutterError.onError!(
        FlutterErrorDetails(
          exception: Exception('bad input from jo@example.com'),
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(presented, hasLength(1));
      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single.fatal, isFalse);
      expect(reporter.reports.single.message, contains('[email]'));
    });

    test(
      'PlatformDispatcher.onError reports uncaught async errors as fatal and marks them handled',
      () async {
        final reporter = _RecordingReporter();
        installErrorHandlers(reporter);

        final handled = PlatformDispatcher.instance.onError!(
          StateError('boom'),
          StackTrace.current,
        );
        await Future<void>.delayed(Duration.zero);

        expect(handled, isTrue);
        expect(reporter.reports.single.fatal, isTrue);
      },
    );

    test('runGuarded catches errors that escape the app zone', () async {
      final reporter = _RecordingReporter();
      await runGuarded(reporter, () async {
        Future<void>.delayed(
          Duration.zero,
          () => throw StateError('escaped 0810000000'),
        );
      });
      await Future<void>.delayed(const Duration(milliseconds: 20));

      expect(reporter.reports, hasLength(1));
      expect(reporter.reports.single.message, contains('[phone]'));
      expect(reporter.reports.single.fatal, isTrue);
    });
  });
}
