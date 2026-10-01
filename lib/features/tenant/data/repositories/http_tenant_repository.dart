import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/diagnostics/crash_reporter.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

class HttpTenantRepository implements TenantRepository {
  /// [crashReporter] receives a non-fatal report when directory entries had
  /// to be skipped (release builds only; [isRelease] is injectable for tests).
  HttpTenantRepository(this._api, {void Function(String line)? log, this._crashReporter, this._isRelease = kReleaseMode})
      : _log = log ?? _debugLog;

  static const _timeout = Duration(seconds: 10);

  final ApiClient _api;
  final void Function(String line) _log;
  final CrashReporter? _crashReporter;
  final bool _isRelease;

  static void _debugLog(String line) {
    if (kDebugMode) debugPrint(line);
  }

  /// A malformed entry is skipped (fail closed per entry, not per list), so
  /// one bad record cannot hide every other ISP. A wrong-shaped list itself
  /// still fails, and so does a list in which nothing is usable. The skipped
  /// count travels with the result ([TenantDirectory.isIncomplete]).
  /// Directory pages followed at most (bounded: a misbehaving server cannot
  /// keep the app paging forever).
  static const _maxDirectoryPages = 10;

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async {
    final tenants = <Tenant>[];
    var skipped = 0;
    var entryCount = 0;
    String? cursor;
    final seen = <String>{};
    for (var page = 0; page < _maxDirectoryPages; page++) {
      final result = await _api.get<(List<Tenant>, int, int, String?)>(
        '/v1/tenants',
        authenticated: false,
        timeout: _timeout,
        query: {'cursor': ?cursor},
        decode: _decodePage,
      );
      final failure = result.match((f) => f, (_) => null);
      if (failure != null) return Left(failure);
      final (pageTenants, pageSkipped, pageEntries, next) = result.getOrElse(
        (_) => throw StateError('unreachable'),
      );
      tenants.addAll(pageTenants);
      skipped += pageSkipped;
      entryCount += pageEntries;
      if (next == null || next.isEmpty || !seen.add(next)) break;
      cursor = next;
    }
    // Count only: never the entry itself.
    if (skipped > 0) {
      _log('tenant directory: skipped $skipped malformed entries');
      if (_isRelease) {
        unawaited(_crashReporter?.recordError(
          FormatException('tenant directory: skipped $skipped malformed entries'),
          null,
          reason: 'malformed tenant directory entries',
        ));
      }
    }
    if (tenants.isEmpty && entryCount > 0) {
      return const Left(ServerFailure('We received an unexpected response. Please try again.'));
    }
    return Right(TenantDirectory(tenants, skipped: skipped));
  }

  /// One page: usable tenants, skipped entries, entries seen, next cursor. A
  /// malformed entry is skipped (fail closed per entry, not per list); a
  /// wrong-shaped page itself throws.
  static (List<Tenant>, int, int, String?) _decodePage(Object? data) {
    final map = data! as Map;
    final entries = map['tenants']! as List;
    final tenants = <Tenant>[];
    var skipped = 0;
    for (final entry in entries) {
      try {
        tenants.add(Tenant.fromJson(Map<String, Object?>.from(entry as Map)));
      } on Object {
        skipped++;
      }
    }
    final next = map['next_cursor'];
    return (tenants, skipped, entries.length, next is String ? next : null);
  }

  /// The response must describe the tenant that was asked for: a mismatched
  /// slug (proxy, cache or backend bug) is rejected rather than applied.
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) => _api.get<AppConfig>(
        '/v1/app-config',
        authenticated: false,
        query: {'tenant': slug},
        timeout: _timeout,
        decode: (data) {
          final config = AppConfig.fromJson(Map<String, Object?>.from(data! as Map));
          if (config.tenant.slug != slug) throw const FormatException('Tenant mismatch');
          return config;
        },
      );
}
