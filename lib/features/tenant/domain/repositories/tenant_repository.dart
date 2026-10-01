import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';

abstract class TenantRepository {
  /// Directory of active, listed ISPs (`GET /v1/tenants`).
  Future<Either<Failure, List<Tenant>>> listTenants();

  /// Branding, flags, legal versions and minimum app version for [slug].
  /// An unknown or suspended tenant is a `NotFoundFailure`.
  Future<Either<Failure, AppConfig>> getAppConfig(String slug);
}
