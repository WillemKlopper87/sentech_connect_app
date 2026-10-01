import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

const _pass = Plan(
  id: 'pass_day',
  name: 'Day pass',
  priceCents: 1999,
  dataDescription: '1 GB · 1 day',
  speedMbps: 10,
  category: ProductCategory.voucher,
);

void main() {
  group('formatRands', () {
    test('formats integer cents as rands with two decimals', () {
      expect(formatRands(54900), 'R549.00');
      expect(formatRands(1999), 'R19.99');
      expect(formatRands(5), 'R0.05');
      expect(formatRands(0), 'R0.00');
      expect(formatRands(-1250), '-R12.50');
    });

    test('wholeRands drops ".00" only when there are no cents', () {
      expect(formatRands(54900, wholeRands: true), 'R549');
      expect(formatRands(54950, wholeRands: true), 'R549.50');
    });
  });

  test('cart totals are exact integer cents', () async {
    final cart = CartCubit()..addItem(_pass);
    cart.setQuantity('pass_day', 3);
    expect(cart.state.items.single.lineTotalCents, 5997);
    expect(cart.state.totalCents, 5997);
    expect(formatRands(cart.state.totalCents), 'R59.97');
    await cart.close();
  });

  test('orders persisted by older builds (totalRands) are rounded to cents', () {
    Order legacy(num rands) => Order.fromJson({
          'id': 'o1',
          'orderNumber': 'SEN-1',
          'planName': 'Home 100',
          'totalRands': rands,
          'status': 'paid',
        });
    // 19.99 * 100 == 1998.9999999999998 and 0.29 * 100 == 28.999999999999996:
    // truncating instead of rounding would give 1998 and 28.
    expect(legacy(19.99).totalCents, 1999);
    expect(legacy(0.29).totalCents, 29);
    final order = legacy(549.99);
    expect(order.totalCents, 54999);
    expect(order.toJson()['totalCents'], 54999);
    expect(Order.fromJson(order.toJson()), order);
  });

  test('an order with neither totalCents nor totalRands is rejected, not read as R0.00', () {
    expect(
      () => Order.fromJson({'id': 'o1', 'orderNumber': 'SEN-1', 'planName': 'Home 100', 'status': 'paid'}),
      throwsFormatException,
    );
  });
}
