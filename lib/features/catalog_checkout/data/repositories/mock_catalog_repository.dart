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
        priceRands: 399,
        dataDescription: '50GB anytime data',
        speedMbps: 50,
        category: ProductCategory.home5g,
      ),
      Plan(
        id: 'home_100',
        name: 'Home 100',
        priceRands: 549,
        dataDescription: '100GB anytime data',
        speedMbps: 100,
        category: ProductCategory.home5g,
        isFeatured: true,
      ),
      Plan(
        id: 'home_unlimited',
        name: 'Home Unlimited',
        priceRands: 799,
        dataDescription: 'Uncapped data',
        speedMbps: 100,
        category: ProductCategory.home5g,
      ),
      // MiFi
      Plan(
        id: 'mifi_20',
        name: 'MiFi 20',
        priceRands: 199,
        dataDescription: '20GB anytime data',
        speedMbps: 50,
        category: ProductCategory.mifi,
      ),
      Plan(
        id: 'mifi_50',
        name: 'MiFi 50',
        priceRands: 349,
        dataDescription: '50GB anytime data',
        speedMbps: 50,
        category: ProductCategory.mifi,
        isFeatured: true,
      ),
      // Vouchers
      Plan(
        id: 'voucher_5gb',
        name: '5GB Wi-Fi Voucher',
        priceRands: 59,
        dataDescription: 'Valid for 30 days',
        speedMbps: 50,
        category: ProductCategory.voucher,
      ),
      Plan(
        id: 'voucher_20gb',
        name: '20GB Wi-Fi Voucher',
        priceRands: 199,
        dataDescription: 'Valid for 30 days',
        speedMbps: 50,
        category: ProductCategory.voucher,
        isFeatured: true,
      ),
    ]);
  }
}
