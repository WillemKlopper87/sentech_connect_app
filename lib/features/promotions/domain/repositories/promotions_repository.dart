import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/promotions/domain/entities/promotion.dart';

/// Real implementation queries Sentech's promotions/CRM campaign API —
/// not yet named, same open-integration status as the coverage and CPE
/// telemetry APIs (see docs/prompt-critique.md).
abstract class PromotionsRepository {
  Future<Either<Failure, List<Promotion>>> getActivePromotions();

  /// Loyalty points balance shown alongside promotions.
  Future<Either<Failure, int>> getLoyaltyPoints();
}
