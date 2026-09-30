import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

/// Orders are persisted, resumable entities: create -> RICA -> pay ->
/// confirmation. Real implementation talks to the order service, and to each
/// provider's hosted/tokenised checkout (Ozow / PayShap / Peach) — no raw
/// card form is ever built in-app, per docs/reconciled-spec.md §3.D and the
/// PCI-DSS critique fix. The server owns prices/totals and order numbers;
/// the client only sends what is in the cart.
abstract class CheckoutRepository {
  /// Creates a `pendingVerification` order from the cart. Any earlier
  /// unpaid order is superseded, so there is at most one open order.
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items});

  Future<Either<Failure, Order>> getOrder(String orderId);

  /// The customer's unpaid order, if any — drives the dashboard "resume"
  /// banner.
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
