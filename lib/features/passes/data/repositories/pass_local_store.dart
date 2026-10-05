import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

/// Device-only personal pass data. All writes and wipes share one queue so a
/// load started before logout cannot restore data after the wipe.
class PassLocalStore {
  static const cachePrefix = 'passes_cache:';
  static const alertsPrefix = 'usage_alerts:';
  int _epoch = 0;
  Future<void> _tail = Future.value();

  int get generation => _epoch;

  Future<T> _serial<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _, StackTrace stack) {});
    return result;
  }

  String _cacheKey(String tenant, String user) => '$cachePrefix$tenant:$user';
  String _alertKey(String tenant, String user) => '$alertsPrefix$tenant:$user';

  Future<PassLoad?> read(
    String tenant,
    String user, {
    required bool includeExpired,
    required bool Function() isCurrent,
  }) async {
    final epoch = _epoch;
    final prefs = await SharedPreferences.getInstance();
    if (epoch != _epoch || !isCurrent()) return null;
    try {
      final raw = prefs.getString(_cacheKey(tenant, user));
      if (raw == null) return null;
      final entries = jsonDecode(raw) as Map<String, dynamic>;
      final entry =
          entries[includeExpired ? 'all' : 'current'] as Map<String, dynamic>?;
      if (entry == null) return null;
      final loadedAt = DateTime.fromMillisecondsSinceEpoch(
        entry['loadedAt'] as int,
        isUtc: true,
      );
      final passes = [
        for (final raw in entry['items'] as List)
          passFromJson(Map<String, Object?>.from(raw as Map)),
      ];
      if (epoch != _epoch || !isCurrent()) return null;
      return PassLoad(passes: passes, loadedAt: loadedAt, fromCache: true);
    } on Object {
      return null;
    }
  }

  Future<void> save(
    String tenant,
    String user,
    PassLoad load, {
    required bool includeExpired,
    required bool Function() isCurrent,
  }) {
    final epoch = _epoch;
    return _serial(() async {
      if (epoch != _epoch || !isCurrent()) return;
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _epoch || !isCurrent()) return;
      final key = _cacheKey(tenant, user);
      Map<String, dynamic> entries;
      try {
        entries =
            jsonDecode(prefs.getString(key) ?? '{}') as Map<String, dynamic>;
      } on Object {
        entries = {};
      }
      entries[includeExpired ? 'all' : 'current'] = {
        'loadedAt': load.loadedAt.toUtc().millisecondsSinceEpoch,
        'items': load.passes.map(_passJson).toList(),
      };
      if (epoch != _epoch || !isCurrent()) return;
      await prefs.setString(key, jsonEncode(entries));
      // Wipe is queued after this write. A session change without a wipe is
      // still rejected by the scope and cannot be returned to another user.
      if (epoch != _epoch || !isCurrent()) await prefs.remove(key);
    });
  }

  Future<bool> alertsEnabled(
    String tenant,
    String user, {
    required bool Function() isCurrent,
  }) async {
    final epoch = _epoch;
    final prefs = await SharedPreferences.getInstance();
    return epoch == _epoch &&
        isCurrent() &&
        (prefs.getBool('${_alertKey(tenant, user)}:enabled') ?? false);
  }

  Future<void> setAlertsEnabled(
    String tenant,
    String user,
    bool value, {
    required bool Function() isCurrent,
  }) {
    final epoch = _epoch;
    return _serial(() async {
      if (epoch != _epoch || !isCurrent()) return;
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _epoch || !isCurrent()) return;
      final key = '${_alertKey(tenant, user)}:enabled';
      await prefs.setBool(key, value);
      if (epoch != _epoch || !isCurrent()) await prefs.remove(key);
    });
  }

  Future<Set<String>> sentAlerts(
    String tenant,
    String user, {
    required bool Function() isCurrent,
  }) async {
    final epoch = _epoch;
    final prefs = await SharedPreferences.getInstance();
    return epoch == _epoch && isCurrent()
        ? (prefs.getStringList('${_alertKey(tenant, user)}:sent') ?? []).toSet()
        : {};
  }

  Future<void> markSent(
    String tenant,
    String user,
    Set<String> ids, {
    required bool Function() isCurrent,
  }) {
    final epoch = _epoch;
    return _serial(() async {
      if (epoch != _epoch || !isCurrent()) return;
      final prefs = await SharedPreferences.getInstance();
      if (epoch != _epoch || !isCurrent()) return;
      final key = '${_alertKey(tenant, user)}:sent';
      final current = (prefs.getStringList(key) ?? []).toSet();
      await prefs.setStringList(key, {...current, ...ids}.toList());
      if (epoch != _epoch || !isCurrent()) await prefs.remove(key);
    });
  }

  Future<void> clearPersonalData() {
    _epoch++;
    return _serial(() async {
      final prefs = await SharedPreferences.getInstance();
      for (final key
          in prefs
              .getKeys()
              .where(
                (k) => k.startsWith(cachePrefix) || k.startsWith(alertsPrefix),
              )
              .toList()) {
        await prefs.remove(key);
      }
    });
  }

  static Map<String, Object?> _passJson(Pass p) => {
    'id': p.id,
    'order_id': p.orderId,
    'source': p.source.name,
    'product_name': p.productName,
    'status': p.status.name,
    'starts_at': p.startsAt.toUtc().toIso8601String(),
    'expires_at': p.expiresAt.toUtc().toIso8601String(),
    'duration_minutes': p.durationMinutes,
    'data_mb': p.dataMb,
    'speed_kbps': p.speedKbps,
    'max_devices': p.maxDevices,
    'used_bytes': p.usedBytes,
  };
}
