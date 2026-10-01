import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/privacy/presentation/pages/data_export_page.dart';
import 'package:sentech_connect_app/features/privacy/presentation/privacy_failure_message.dart';
import 'package:sentech_connect_app/l10n/app_localizations_en.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';

import 'helpers/test_setup.dart';

const _json = '{\n  "profile": {\n    "phone_e164": "+27821234567",\n    "display_name": "Thandi Mokoena"\n  }\n}';

void main() {
  setUpAppTests();

  group('DataExportPage', () {
    testWidgets('renders the export, is capture-protected and selectable', (tester) async {
      await tester.pumpWidget(const MaterialApp(home: DataExportPage(json: _json)));
      await tester.pumpAndSettle();

      expect(find.text('Your data'), findsOneWidget);
      expect(find.byType(SelectableText), findsOneWidget);
      expect(tester.widget<SelectableText>(find.byType(SelectableText)).data, _json);
      expect(find.byType(SecureScreen), findsOneWidget);
      expect(ScreenSecurity.isProtected, isTrue);
      final calls = [
        for (final c in platformCalls)
          if (c.method == 'setSecure') (c.arguments as Map)['enabled'] as bool,
      ];
      expect(calls, [true]);

      await tester.pumpWidget(const MaterialApp(home: Text('elsewhere')));
      expect(ScreenSecurity.isProtected, isFalse);
    });

    testWidgets('showing and selecting the export never writes it to the debug log', (tester) async {
      final logged = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) => logged.add(message ?? '');
      try {
        await tester.pumpWidget(const MaterialApp(home: DataExportPage(json: _json)));
        await tester.pumpAndSettle();
        await tester.longPress(find.byType(SelectableText));
        await tester.pumpAndSettle();
      } finally {
        debugPrint = originalDebugPrint;
      }

      for (final line in logged) {
        expect(line, isNot(contains('27821234567')));
        expect(line, isNot(contains('Thandi')));
      }
    });
  });

  group('privacyFailureMessage', () {
    final l10n = AppLocalizationsEn();

    test('shows the server reason for refusals (4xx detail)', () {
      expect(privacyFailureMessage(l10n, const ValidationFailure('Finish your open orders first.', 'open_orders')), 'Finish your open orders first.');
      expect(privacyFailureMessage(l10n, const ServerFailure('Export is not allowed.')), 'Export is not allowed.');
    });

    test('a bare problem title such as Conflict is not shown to the customer', () {
      expect(privacyFailureMessage(l10n, const ValidationFailure('Conflict', 'conflict', false)), l10n.accountRequestFailed);
    });

    test('never shows generic server text, and maps offline and rate limits to localised text', () {
      expect(privacyFailureMessage(l10n, const ServerFailure()), l10n.accountRequestFailed);
      expect(privacyFailureMessage(l10n, const ServerFailure('We received an unexpected response. Please try again.')), l10n.accountRequestFailed);
      expect(privacyFailureMessage(l10n, const NetworkFailure()), l10n.accountRequestOffline);
      expect(privacyFailureMessage(l10n, const RateLimitedFailure()), l10n.accountRequestRateLimited);
      expect(privacyFailureMessage(l10n, null), l10n.accountRequestFailed);
    });
  });
}
