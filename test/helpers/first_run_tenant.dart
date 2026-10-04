import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

class FirstRunTenantRepository implements TenantRepository {
  FirstRunTenantRepository({
    required bool cpe,
    bool hotspot = true,
    bool rica = false,
    TenantBranding branding = const TenantBranding(),
  }) : config = AppConfig(
         tenant: Tenant(
           slug: 'sentech',
           name: 'Sentech',
           type: 'operator',
           branding: branding,
         ),
         minAppVersion: '1.0.0',
         featureFlags: FeatureFlags(
           cpe: cpe,
           hotspotPasses: hotspot,
           rica: rica,
         ),
         legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-29'),
       );
  final AppConfig config;
  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async =>
      Right(config);
  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async =>
      Right(TenantDirectory([config.tenant]));
}

Future<TenantCubit> firstRunTenant({
  required bool cpe,
  bool hotspot = true,
  TenantBranding branding = const TenantBranding(),
}) async {
  final cubit = TenantCubit(
    repository: FirstRunTenantRepository(
      cpe: cpe,
      hotspot: hotspot,
      branding: branding,
    ),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(),
  );
  await cubit.bootstrap();
  return cubit;
}
