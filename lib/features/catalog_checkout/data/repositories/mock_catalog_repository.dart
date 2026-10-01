import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';

class MockCatalogRepository implements CatalogRepository {
  MockCatalogRepository([SimulatedNetwork? network]) : _network = network ?? SimulatedNetwork();

  final SimulatedNetwork _network;

  @override
  Future<Either<Failure, List<Plan>>> getProducts() async {
    await Future.delayed(const Duration(milliseconds: 400));
    if (_network.failure case final failure?) return Left(failure);
    return const Right([
      // Home 5G
      Plan(
        id: 'home_50',
        name: 'Home 50',
        priceCents: 39900,
        dataDescription: '50GB anytime data',
        speedMbps: 50,
        category: ProductCategory.home5g,
      ),
      Plan(
        id: 'home_100',
        name: 'Home 100',
        priceCents: 54900,
        dataDescription: '100GB anytime data',
        speedMbps: 100,
        category: ProductCategory.home5g,
        isFeatured: true,
      ),
      Plan(
        id: 'home_unlimited',
        name: 'Home Unlimited',
        priceCents: 79900,
        dataDescription: 'Uncapped data',
        speedMbps: 100,
        category: ProductCategory.home5g,
      ),
      // MiFi
      Plan(
        id: 'mifi_20',
        name: 'MiFi 20',
        priceCents: 19900,
        dataDescription: '20GB anytime data',
        speedMbps: 50,
        category: ProductCategory.mifi,
      ),
      Plan(
        id: 'mifi_50',
        name: 'MiFi 50',
        priceCents: 34900,
        dataDescription: '50GB anytime data',
        speedMbps: 50,
        category: ProductCategory.mifi,
        isFeatured: true,
      ),
      // Vouchers
      Plan(
        id: 'voucher_5gb',
        name: '5GB Wi-Fi Voucher',
        priceCents: 5900,
        dataDescription: 'Valid for 30 days',
        speedMbps: 50,
        category: ProductCategory.voucher,
      ),
      Plan(
        id: 'voucher_20gb',
        name: '20GB Wi-Fi Voucher',
        priceCents: 19900,
        dataDescription: 'Valid for 30 days',
        speedMbps: 50,
        category: ProductCategory.voucher,
        isFeatured: true,
      ),
    ]);
  }
}
