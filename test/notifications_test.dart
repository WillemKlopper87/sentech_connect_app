import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/notifications/notification_permission_cubit.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/shared/widgets/notification_rationale_sheet.dart';

void main() {
  group('NotificationPermissionCubit', () {
    test('reads the current status and updates after the system prompt', () async {
      final service = FakeNotificationService();
      final cubit = NotificationPermissionCubit(service);
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, NotificationPermissionStatus.denied);

      await cubit.requestOrOpenSettings();
      expect(cubit.state, NotificationPermissionStatus.granted);
      expect(service.requestCalls, 1);
    });

    test('once permanently denied it opens system settings instead of prompting', () async {
      final service = FakeNotificationService(status: NotificationPermissionStatus.permanentlyDenied);
      final cubit = NotificationPermissionCubit(service);
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);

      await cubit.requestOrOpenSettings();
      expect(service.requestCalls, 0);
      expect(service.settingsOpened, 1);
    });
  });

  group('rationale sheet', () {
    late FakeNotificationService service;
    NotificationPermissionStatus? outcome;
    var finished = false;

    setUp(() {
      service = FakeNotificationService();
      outcome = null;
      finished = false;
    });

    Future<void> open(WidgetTester tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () async {
                outcome = await showNotificationRationale(context, service: service);
                finished = true;
              },
              child: const Text('ask'),
            ),
          ),
        ),
      ));
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
    }

    testWidgets('explains why BEFORE the system prompt, which only appears after "Allow"', (tester) async {
      await open(tester);
      expect(find.text('Stay in the loop'), findsOneWidget);
      expect(service.requestCalls, 0);

      await tester.tap(find.text('Allow notifications'));
      await tester.pumpAndSettle();
      expect(service.requestCalls, 1);
      expect(outcome, NotificationPermissionStatus.granted);
    });

    testWidgets('"Not now" never triggers the system prompt', (tester) async {
      await open(tester);
      await tester.tap(find.text('Not now'));
      await tester.pumpAndSettle();
      expect(finished, isTrue);
      expect(outcome, isNull);
      expect(service.requestCalls, 0);
    });

    testWidgets('when already granted there is nothing to explain', (tester) async {
      service.status = NotificationPermissionStatus.granted;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async {
              outcome = await showNotificationRationale(context, service: service);
            },
            child: const Text('ask'),
          ),
        ),
      ));
      await tester.tap(find.text('ask'));
      await tester.pumpAndSettle();
      expect(find.text('Stay in the loop'), findsNothing);
      expect(outcome, NotificationPermissionStatus.granted);
    });
  });
}
