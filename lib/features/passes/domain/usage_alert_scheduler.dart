// ignore_for_file: prefer_initializing_formals

import 'package:sentech_connect_app/features/passes/domain/usage_alert_policy.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/core/notifications/notification_service.dart';
import 'package:sentech_connect_app/features/passes/data/repositories/pass_local_store.dart';

abstract class UsageAlertScheduler {
  bool get isAvailable;
  Future<void> schedule(List<UsageAlert> alerts);
}

/// No delivery transport is configured yet. Never record an alert as sent.
class NoopUsageAlertScheduler implements UsageAlertScheduler {
  const NoopUsageAlertScheduler();
  @override
  bool get isAvailable => false;
  @override
  Future<void> schedule(List<UsageAlert> alerts) async {}
}

/// Schedules only for the currently signed-in, opted-in customer. A no-op
/// transport never records an alert as sent.
class UsageAlertCoordinator {
  UsageAlertCoordinator({
    required ApiClient api,
    required TokenStore tokens,
    required PassLocalStore store,
    required UsageAlertScheduler scheduler,
    required DateTime Function() now,
    NotificationService? notifications,
  }) : _api = api,
       _tokens = tokens,
       _store = store,
       _scheduler = scheduler,
       _now = now,
       _notifications = notifications;
  final ApiClient _api;
  final TokenStore _tokens;
  final PassLocalStore _store;
  final UsageAlertScheduler _scheduler;
  final DateTime Function() _now;
  final NotificationService? _notifications;
  final Set<String> _pending = {};

  bool get isAvailable => _scheduler.isAvailable;

  Future<bool> isEnabled() async {
    if (!isAvailable) return false;
    final scope = await _api.captureScope();
    final generation = _store.generation;
    final token = await _tokens.read();
    if (token == null || token.tenantSlug != _api.tenant.slug) return false;
    return _store.alertsEnabled(
      token.tenantSlug,
      token.customerId,
      isCurrent: () =>
          scope.isCurrent &&
          generation == _store.generation &&
          token.tenantSlug == _api.tenant.slug,
    );
  }

  Future<void> setEnabled(bool value) async {
    if (!isAvailable) return;
    final scope = await _api.captureScope();
    final generation = _store.generation;
    final token = await _tokens.read();
    if (token == null || token.tenantSlug != _api.tenant.slug) return;
    await _store.setAlertsEnabled(
      token.tenantSlug,
      token.customerId,
      value,
      isCurrent: () =>
          scope.isCurrent &&
          generation == _store.generation &&
          token.tenantSlug == _api.tenant.slug,
    );
  }

  Future<void> onLoaded(List<Pass> passes) async {
    if (!_scheduler.isAvailable) return;
    final scope = await _api.captureScope();
    final generation = _store.generation;
    final token = await _tokens.read();
    if (token == null || token.tenantSlug != _api.tenant.slug) return;
    final tenant = token.tenantSlug;
    final user = token.customerId;
    bool current() =>
        scope.isCurrent &&
        generation == _store.generation &&
        tenant == _api.tenant.slug;
    if (!current() ||
        !await _store.alertsEnabled(tenant, user, isCurrent: current)) {
      return;
    }
    if (_notifications case final notifications?) {
      if (await notifications.permissionStatus() !=
              NotificationPermissionStatus.granted ||
          !current()) {
        return;
      }
    }
    final sent = await _store.sentAlerts(tenant, user, isCurrent: current);
    if (!current()) return;
    final pendingForUser = _pending
        .where((id) => id.startsWith('$tenant:$user:'))
        .map((id) => id.substring('$tenant:$user:'.length))
        .toSet();
    final due = [
      for (final pass in passes)
        ...UsageAlertPolicy.due(
          pass,
          now: _now(),
          alreadySent: {...sent, ...pendingForUser},
        ),
    ];
    if (due.isEmpty || !current()) return;
    final ids = due.map((a) => a.id).toSet();
    final scopedIds = ids.map((id) => '$tenant:$user:$id').toSet();
    _pending.addAll(scopedIds);
    try {
      await _scheduler.schedule(due);
      if (current()) {
        await _store.markSent(tenant, user, ids, isCurrent: current);
      }
    } finally {
      _pending.removeAll(scopedIds);
    }
  }
}
