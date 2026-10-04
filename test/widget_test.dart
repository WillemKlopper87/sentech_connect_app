import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/app.dart';
import 'helpers/test_setup.dart';

void main() {
  setUpAppTests();

  testWidgets('App boots through the splash to the login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const SentechConnectApp());
    await tester.pump(); // splash first frame
    await tester.pump(const Duration(milliseconds: 1300)); // splash auto-advance delay
    await tester.pumpAndSettle();

    expect(find.text('Hello!'), findsOneWidget);
    expect(find.text('Send code'), findsOneWidget);
  });
}
