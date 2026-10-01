import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/startup_error_app.dart';

void main() {
  testWidgets('the startup error app shows a short, detail-free message', (tester) async {
    await tester.pumpWidget(buildStartupErrorApp());
    expect(find.text('App configuration error — please reinstall or contact support'), findsOneWidget);
    // One text only: no defines, URLs, stack traces or exception names.
    expect(find.byType(Text), findsOneWidget);
    expect(find.byType(Scaffold), findsOneWidget);
  });

  testWidgets('it needs no locator, localisation or other service', (tester) async {
    // Pumped on a bare binding: any service lookup would throw.
    await tester.pumpWidget(buildStartupErrorApp());
    expect(tester.takeException(), isNull);
  });
}
