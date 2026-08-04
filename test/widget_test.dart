import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'package:sentech_connect_app/app/locator.dart';

void main() {
  setUpAll(() {
    setupLocator();
  });

  testWidgets('App boots through the splash to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(SentechConnectApp());
    await tester.pump(); // splash first frame
    await tester.pump(const Duration(milliseconds: 1300)); // splash auto-advance delay
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Log in'), findsOneWidget);
  });
}
