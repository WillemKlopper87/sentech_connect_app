import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/theme/color_contrast.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'helpers/pump_themed.dart';
import 'helpers/screens.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();
  for (final brightness in Brightness.values) {
    testWidgets(
      'Our pick is editorial navy-on-amber with readable label in $brightness',
      (tester) async {
        await pumpThemed(
          tester,
          buildScreenForTest(
            'shop',
            lookupAppLocalizations(const Locale('en')),
          ),
          brightness: brightness,
          textScale: 2,
          size: const Size(360, 690),
        );
        await tester.pumpAndSettle();
        final text = tester.widget<Text>(find.text('Our pick').first);
        expect(text.style!.fontSize, greaterThanOrEqualTo(13));
        expect(text.style!.color, const Color(0xFF003A70));
        final containers = tester.widgetList<Container>(
          find.ancestor(
            of: find.text('Our pick').first,
            matching: find.byType(Container),
          ),
        );
        final badge = containers.firstWhere(
          (c) =>
              c.decoration is BoxDecoration &&
              (c.decoration! as BoxDecoration).color == const Color(0xFFFAA61A),
        );
        expect(
          ColorContrast.ratio(
            text.style!.color!,
            (badge.decoration! as BoxDecoration).color!,
          ),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          find.bySemanticsLabel(RegExp('Selected by us for you')),
          findsWidgets,
        );
        expect(tester.takeException(), isNull);
      },
    );
  }
}
