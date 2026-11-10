import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';

/// The 5G data allowance of one fixed-wireless service and the paid unlocks
/// for it. Refusals (404 when the feature is off or the service is not
/// eligible) come back as [FiveGNotAvailableFailure]. Paying for an unlock
/// goes through the shared checkout (`PaymentCubit`), not through here.
abstract class FiveGRepository {
  Future<Either<Failure, FiveGUsage>> getUsage(String serviceId);

  /// Creates an unlock order for [productCode] (one of the offers). Reusing
  /// [idempotencyKey] after a lost response returns the same order.
  Future<Either<Failure, Order>> createUnlockOrder(
    String serviceId, {
    required String productCode,
    required String idempotencyKey,
  });
}
