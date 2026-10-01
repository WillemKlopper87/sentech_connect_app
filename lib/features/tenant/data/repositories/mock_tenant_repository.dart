import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/app_config.dart';
import 'package:sentech_connect_app/features/tenant/domain/entities/tenant.dart';
import 'package:sentech_connect_app/features/tenant/domain/repositories/tenant_repository.dart';

/// Demo flavor: Sentech is the only tenant and every feature flag is on.
class MockTenantRepository implements TenantRepository {
  MockTenantRepository([SimulatedNetwork? network]) : _network = network ?? SimulatedNetwork();

  static const sentech = Tenant(slug: 'sentech', name: 'Sentech', type: 'operator');
  static const demoConfig = AppConfig(
    tenant: sentech,
    minAppVersion: '1.0.0',
    featureFlags: FeatureFlags.demo,
    legal: LegalVersions(terms: '2026-09-30', privacy: '2026-09-30'),
  );

  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, List<Tenant>>> listTenants() async {
    if (_network.failure case final failure?) return Left(failure);
    return const Right([sentech]);
  }

  @override
  Future<Either<Failure, AppConfig>> getAppConfig(String slug) async {
    if (_network.failure case final failure?) return Left(failure);
    if (slug != sentech.slug) return const Left(NotFoundFailure('Unknown provider.'));
    return const Right(demoConfig);
  }
}
