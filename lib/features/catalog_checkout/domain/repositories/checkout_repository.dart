import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';

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

  /// Starts (or resumes) payment of an order that needs no further identity
  /// check and returns where the customer pays. Idempotent on the server:
  /// calling again returns the same open attempt. The order only becomes
  /// `paid` when the gateway's server-to-server notification arrives, so
  /// callers poll [getOrder] afterwards; the app never marks it paid.
  Future<Either<Failure, PaymentHandoff>> startPayment({
    required String orderId,
  });

  /// Removes locally held order data (logout / account deletion).
  Future<void> clearLocalOrders();
}
