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
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() => _api.get<TenantDirectory>(
        '/v1/tenants',
        authenticated: false,
        timeout: _timeout,
        decode: (data) {
          final entries = (data! as Map)['tenants']! as List;
          final tenants = <Tenant>[];
          var skipped = 0;
          for (final entry in entries) {
            try {
              tenants.add(Tenant.fromJson(Map<String, Object?>.from(entry as Map)));
            } on Object {
              skipped++;
            }
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
          if (tenants.isEmpty && entries.isNotEmpty) throw const FormatException('No usable tenants');
          return TenantDirectory(tenants, skipped: skipped);
        },
      );

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
