import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

/// Real implementation talks to each provider's hosted/tokenised checkout
/// (Ozow / PayShap / Peach) — no raw card form is ever built in-app,
/// per docs/reconciled-spec.md §3.D and the PCI-DSS critique fix.
abstract class CheckoutRepository {
  Future<Either<Failure, Order>> pay({
    required List<CartItem> items,
    required PaymentMethod method,
  });
}
