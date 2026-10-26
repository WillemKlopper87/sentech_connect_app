import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/pass_local_store.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/usage_alert_policy.dart';
import 'package:sentech_connect_app/features/passes/domain/usage_alert_scheduler.dart';

import 'helpers/api_harness.dart';

class _RecordingScheduler implements UsageAlertScheduler {
  final calls = <UsageAlert>[];
  @override
  bool get isAvailable => true;
  @override
  Future<void> schedule(List<UsageAlert> alerts) async => calls.addAll(alerts);
}

DateTime sast(int hour, int minute) =>
    DateTime.utc(2026, 10, 3, hour - 2, minute);
Pass pass({
  int dataMb = 1000,
  int usedMb = 810,
  PassStatus status = PassStatus.active,
  DateTime? startsAt,
  DateTime? expiresAt,
}) => Pass(
  id: 'p1',
  productName: 'Day Pass',
  status: status,
  startsAt: startsAt ?? sast(10, 0).subtract(const Duration(hours: 1)),
  expiresAt: expiresAt ?? sast(18, 0),
  durationMinutes: 480,
  dataMb: dataMb,
  maxDevices: 1,
  usedBytes: usedMb * 1024 * 1024,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));
  test('80% alert once, never in quiet hours', () {
    final p = pass();
    expect(
      UsageAlertPolicy.due(
        p,
        now: sast(14, 0),
        alreadySent: {},
      ).map((a) => a.id),
      ['${p.id}:80'],
    );
    expect(UsageAlertPolicy.due(p, now: sast(22, 0), alreadySent: {}), isEmpty);
    expect(
      UsageAlertPolicy.due(p, now: sast(14, 0), alreadySent: {'${p.id}:80'}),
      isEmpty,
    );
  });
  test('100% supersedes 80%, expiry is within the final hour', () {
    final p = pass(usedMb: 1000, expiresAt: sast(14, 30));
    expect(
      UsageAlertPolicy.due(
        p,
        now: sast(14, 0),
        alreadySent: {},
      ).map((a) => a.id),
      ['p1:100', 'p1:expiry1h'],
    );
  });
  test('a suspended pass never alerts, even over 80% or inside the last hour', () {
    expect(
      UsageAlertPolicy.due(
        pass(status: PassStatus.suspended, usedMb: 1000, expiresAt: sast(14, 30)),
        now: sast(14, 0),
        alreadySent: {},
      ),
      isEmpty,
    );
  });
  test('scheduled and ended passes have no alerts', () {
    for (final status in [
      PassStatus.scheduled,
      PassStatus.suspended,
      PassStatus.expired,
      PassStatus.exhausted,
      PassStatus.revoked,
    ]) {
      expect(
        UsageAlertPolicy.due(
          pass(status: status),
          now: sast(14, 0),
          alreadySent: {},
        ),
        isEmpty,
      );
    }
  });
  test('quiet hours begin at 21:00 and end at 07:00 SAST', () {
    final p = pass(
      startsAt: sast(7, 0).subtract(const Duration(days: 1)),
      expiresAt: sast(7, 0).add(const Duration(days: 1)),
    );
    expect(
      UsageAlertPolicy.due(p, now: sast(20, 59), alreadySent: {}),
      isNotEmpty,
    );
    expect(UsageAlertPolicy.due(p, now: sast(21, 0), alreadySent: {}), isEmpty);
    expect(UsageAlertPolicy.due(p, now: sast(6, 59), alreadySent: {}), isEmpty);
    expect(
      UsageAlertPolicy.due(p, now: sast(7, 0), alreadySent: {}),
      isNotEmpty,
    );
  });
  test(
    'opt-in gates scheduling and sent IDs are persisted once per customer',
    () async {
      final h = ApiHarness();
      await h.signIn();
      final store = PassLocalStore();
      final scheduler = _RecordingScheduler();
      final coordinator = UsageAlertCoordinator(
        api: h.api,
        tokens: h.tokens,
        store: store,
        scheduler: scheduler,
        now: () => sast(14, 0),
      );
      await coordinator.onLoaded([pass()]);
      expect(scheduler.calls, isEmpty);
      await coordinator.setEnabled(true);
      await coordinator.onLoaded([pass()]);
      await coordinator.onLoaded([pass()]);
      expect(scheduler.calls.map((a) => a.id), ['p1:80']);
      expect(
        await store.sentAlerts(
          'sentech',
          ApiHarness.customerId,
          isCurrent: () => true,
        ),
        {'p1:80'},
      );
    },
  );
  test('no-op scheduler never consumes an alert as sent', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    await store.setAlertsEnabled(
      'sentech',
      ApiHarness.customerId,
      true,
      isCurrent: () => true,
    );
    final coordinator = UsageAlertCoordinator(
      api: h.api,
      tokens: h.tokens,
      store: store,
      scheduler: const NoopUsageAlertScheduler(),
      now: () => sast(14, 0),
    );
    await coordinator.onLoaded([pass()]);
    expect(
      await store.sentAlerts(
        'sentech',
        ApiHarness.customerId,
        isCurrent: () => true,
      ),
      isEmpty,
    );
  });
  test(
    'alert opt-in and sent IDs do not follow a different customer',
    () async {
      final h = ApiHarness();
      await h.signIn();
      final store = PassLocalStore();
      final scheduler = _RecordingScheduler();
      final coordinator = UsageAlertCoordinator(
        api: h.api,
        tokens: h.tokens,
        store: store,
        scheduler: scheduler,
        now: () => sast(14, 0),
      );
      await coordinator.setEnabled(true);
      await coordinator.onLoaded([pass()]);
      await h.tokens.write(
        AuthTokens(
          accessToken: 'other-access',
          refreshToken: 'other-refresh',
          accessExpiresAt: h.now.add(const Duration(minutes: 15)),
          customerId: 'customer-B',
          tenantSlug: 'sentech',
        ),
      );
      expect(await coordinator.isEnabled(), false);
      await coordinator.onLoaded([pass()]);
      expect(scheduler.calls.map((a) => a.id), ['p1:80']);
      expect(
        await store.sentAlerts('sentech', 'customer-B', isCurrent: () => true),
        isEmpty,
      );
    },
  );
  test('revoked system permission suppresses an opted-in alert', () async {
    final h = ApiHarness();
    await h.signIn();
    final store = PassLocalStore();
    final scheduler = _RecordingScheduler();
    final notifications = FakeNotificationService(
      status: NotificationPermissionStatus.denied,
    );
    final coordinator = UsageAlertCoordinator(
      api: h.api,
      tokens: h.tokens,
      store: store,
      scheduler: scheduler,
      now: () => sast(14, 0),
      notifications: notifications,
    );
    await coordinator.setEnabled(true);
    await coordinator.onLoaded([pass()]);
    expect(scheduler.calls, isEmpty);
    notifications.status = NotificationPermissionStatus.granted;
    await coordinator.onLoaded([pass()]);
    expect(scheduler.calls.map((a) => a.id), ['p1:80']);
  });
}
