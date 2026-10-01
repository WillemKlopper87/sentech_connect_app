import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

/// Orders are resumable entities. Online prices and state come from the
/// server; hotspot passes skip RICA. Demo orders retain the verification
/// flow. Payment is handed off to hosted checkout; no card form is built here.
abstract class CheckoutRepository {
  /// Creates an order from product ids and quantities. Reusing
  /// [idempotencyKey] after a timeout returns the same checkout order.
  Future<Either<Failure, Order>> createOrder({
    required List<CartItem> items,
    String? idempotencyKey,
  });

  Future<Either<Failure, Order>> getOrder(String orderId);

  /// The newest open order, including a failed payment, for the resume banner.
  Future<Either<Failure, Order?>> getOpenOrder();

  /// Called after RICA succeeds; moves the order to `awaitingPayment`.
  Future<Either<Failure, Order>> markIdentityVerified(String orderId);

  /// Charges the order. Idempotent: paying an already-paid order returns
  /// it unchanged instead of charging twice. Fails if identity has not
  /// been verified.
  Future<Either<Failure, Order>> pay({
    required String orderId,
    required PaymentMethod method,
  });

  /// Removes locally held order data (logout / account deletion).
  Future<void> clearLocalOrders();
}
