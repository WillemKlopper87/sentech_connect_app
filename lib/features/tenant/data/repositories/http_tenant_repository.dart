import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

class HttpTenantRepository implements TenantRepository {
  HttpTenantRepository(this._api);

  static const _timeout = Duration(seconds: 10);

  final ApiClient _api;

  @override
  Future<Either<Failure, List<Tenant>>> listTenants() => _api.get<List<Tenant>>(
        '/v1/tenants',
        authenticated: false,
        timeout: _timeout,
        decode: (data) {
          final tenants = (data! as Map)['tenants']! as List;
          return [for (final t in tenants) Tenant.fromJson(Map<String, Object?>.from(t as Map))];
        },
      );

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) => _api.get<AppConfig>(
        '/v1/app-config',
        authenticated: false,
        query: {'tenant': slug},
        timeout: _timeout,
        decode: (data) => AppConfig.fromJson(Map<String, Object?>.from(data! as Map)),
      );
}
