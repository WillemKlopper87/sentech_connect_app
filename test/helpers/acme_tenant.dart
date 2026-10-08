import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/tenant_preferences.dart';
import 'package:sentech_connect_app/core/network/tenant_context.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant_directory.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';
import 'package:sentech_connect_app/features/tenant/presentation/bloc/tenant_cubit.dart';

const acmeSupportEmail = 'help@acme.example';
const acmeSupportPhone = '+27 10 555 0100';

class _AcmeRepository implements TenantRepository {
  _AcmeRepository({required this.buyInApp, required this.support});

  final bool buyInApp;
  final SupportChannels support;

  late final config = AppConfig(
    tenant: const Tenant(slug: 'acme-wifi', name: 'Acme Wi-Fi', type: 'operator'),
    minAppVersion: '1.0.0',
    featureFlags: FeatureFlags.demo,
    legal: const LegalVersions(terms: '2026-09-30', privacy: '2026-09-29'),
    support: support,
    buyInApp: buyInApp,
  );

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async => Right(config);

  @override
  Future<Either<Failure, TenantDirectory>> listTenants() async => Right(TenantDirectory([config.tenant]));
}

/// A bootstrapped provider called "Acme Wi-Fi" for the buy-from-provider tests.
Future<TenantCubit> acmeTenant({
  bool buyInApp = true,
  SupportChannels support = const SupportChannels(email: acmeSupportEmail, phone: acmeSupportPhone),
}) async {
  final cubit = TenantCubit(
    repository: _AcmeRepository(buyInApp: buyInApp, support: support),
    context: TenantContext(),
    preferences: InMemoryTenantPreferences(),
  );
  await cubit.bootstrap();
  return cubit;
}
