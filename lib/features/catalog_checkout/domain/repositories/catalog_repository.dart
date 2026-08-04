import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

abstract class CatalogRepository {
  /// Returns the full product catalog across all categories (Home 5G,
  /// MiFi, Vouchers) — the Shop tab filters client-side by category.
  Future<Either<Failure, List<Plan>>> getProducts();
}
