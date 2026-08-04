import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

class MockCheckoutRepository implements CheckoutRepository {
  @override
  Future<Either<Failure, Order>> pay({
    required List<CartItem> items,
    required PaymentMethod method,
  }) async {
    await Future.delayed(const Duration(milliseconds: 900));
    final total = items.fold(0.0, (sum, i) => sum + i.lineTotal);
    final summary = items.length == 1 ? items.first.plan.name : '${items.length} items';
    return Right(Order(
      orderNumber: 'SEN-48213',
      planName: summary,
      totalRands: total,
    ));
  }
}
