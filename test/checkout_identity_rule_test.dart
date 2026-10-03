import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/identity_rule.dart';

CartItem item(ProductCategory category) => CartItem(
  plan: Plan(
    id: category.name,
    name: category.label,
    priceCents: 3500,
    dataDescription: '5 GB',
    speedMbps: 10,
    category: category,
  ),
  quantity: 1,
);

void main() {
  group('requiresIdentityCheck', () {
    test('hotspot (WiFi) passes and WiFi vouchers never need RICA', () {
      expect(
        requiresIdentityCheck(
          ricaFlag: true,
          items: [item(ProductCategory.hotspotPass)],
        ),
        isFalse,
      );
      expect(
        requiresIdentityCheck(
          ricaFlag: true,
          items: [item(ProductCategory.voucher)],
        ),
        isFalse,
      );
      expect(
        requiresIdentityCheck(
          ricaFlag: true,
          items: [
            item(ProductCategory.voucher),
            item(ProductCategory.hotspotPass),
          ],
        ),
        isFalse,
      );
    });

    test('a SIM product (Home 5G or MiFi) needs RICA when the flag is on', () {
      expect(
        requiresIdentityCheck(
          ricaFlag: true,
          items: [item(ProductCategory.home5g)],
        ),
        isTrue,
      );
      expect(
        requiresIdentityCheck(
          ricaFlag: true,
          items: [item(ProductCategory.mifi)],
        ),
        isTrue,
      );
      // A mixed cart is checked: the SIM product needs it.
      expect(
        requiresIdentityCheck(
          ricaFlag: true,
          items: [
            item(ProductCategory.hotspotPass),
            item(ProductCategory.home5g),
          ],
        ),
        isTrue,
      );
    });

    test('with the tenant flag off nothing needs RICA', () {
      for (final c in ProductCategory.values) {
        expect(
          requiresIdentityCheck(ricaFlag: false, items: [item(c)]),
          isFalse,
          reason: c.name,
        );
      }
    });

    test('the categories that need RICA are exactly the SIM products', () {
      expect(ProductCategory.values.where((c) => c.requiresRica).toSet(), {
        ProductCategory.home5g,
        ProductCategory.mifi,
      });
    });
  });

  group('MockCheckoutRepository (demo tenant has rica: true)', () {
    Future<Order> create(ProductCategory category) async =>
        (await MockCheckoutRepository(
          InMemorySecureStore(),
          latency: Duration.zero,
        ).createOrder(items: [item(category)])).getOrElse(
          (f) => throw StateError(f.message),
        );

    test('a WiFi pass order goes straight to payment, never to RICA', () async {
      final order = await create(ProductCategory.hotspotPass);
      expect(order.status, OrderStatus.awaitingPayment);
      expect(AppRoutes.forOrder(order), startsWith('/payment/'));
    });

    test('a WiFi voucher order goes straight to payment', () async {
      expect(
        (await create(ProductCategory.voucher)).status,
        OrderStatus.awaitingPayment,
      );
    });

    test('a Home 5G order still starts with the identity check', () async {
      final order = await create(ProductCategory.home5g);
      expect(order.status, OrderStatus.pendingVerification);
      expect(AppRoutes.forOrder(order), startsWith('/rica/'));
    });
  });
}
