import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/catalog_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/catalog_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/checkout_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/confirmation_page.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/payment_page.dart';

import 'helpers/test_setup.dart';

const pass = Plan(
  id: 'pass',
  name: 'Day Pass',
  priceCents: 4900,
  dataDescription: '5 GB · 1 day',
  speedMbps: 0,
  category: ProductCategory.hotspotPass,
);

class _PassCatalog implements CatalogRepository {
  @override
  Future<Either<Failure, List<Plan>>> getProducts() async =>
      const Right([pass]);
}

void main() {
  setUpAppTests();
  testWidgets(
    'hotspot catalogue selects its available category and omits monthly/zero speed labels',
    (tester) async {
      final catalog = CatalogCubit(_PassCatalog());
      final cart = CartCubit();
      addTearDown(catalog.close);
      addTearDown(cart.close);
      await tester.pumpWidget(
        MaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: catalog),
              BlocProvider.value(value: cart),
            ],
            child: CatalogPage(onOpenCart: () {}, onFindHotspots: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(catalog.state.selectedCategory, ProductCategory.hotspotPass);
      expect(catalog.state.availableCategories, [ProductCategory.hotspotPass]);
      catalog.selectCategory(ProductCategory.voucher);
      expect(catalog.state.selectedCategory, ProductCategory.hotspotPass);
      expect(find.text('Day Pass'), findsOneWidget);
      expect(find.textContaining('0 Mbps'), findsNothing);
      expect(find.textContaining('/mo', findRichText: true), findsNothing);
      expect(find.text('Home 5G'), findsNothing);
    },
  );

  testWidgets('flagged checkout presents payment without RICA copy', (
    tester,
  ) async {
    final cart = CartCubit()..addItem(pass);
    final checkout = CheckoutCubit(
      MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero),
      cart,
    );
    addTearDown(cart.close);
    addTearDown(checkout.close);
    await tester.pumpWidget(
      MaterialApp(
        home: BlocProvider.value(
          value: checkout,
          child: CheckoutPage(
            requiresIdentityCheck: false,
            onOrderCreated: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Continue to payment'), findsOneWidget);
    expect(find.text('Total due'), findsOneWidget);
    expect(find.textContaining('RICA'), findsNothing);
  });

  for (final status in [OrderStatus.expired, OrderStatus.cancelled]) {
    testWidgets(
      '$status shows a closed order without resume/payment controls',
      (tester) async {
        final order = Order(
          id: 'closed',
          orderNumber: 'SC-CLOSED',
          planName: 'Day Pass',
          totalCents: 4900,
          status: status,
        );
        final store = InMemorySecureStore();
        await store.write('orders', '[${_json(order)}]');
        final repo = MockCheckoutRepository(store, latency: Duration.zero);
        final cart = CartCubit()..addItem(pass);
        final payment = PaymentCubit(repo, cart, order.id);
        final confirmation = OrderCubit(repo, order.id);
        addTearDown(cart.close);
        addTearDown(payment.close);
        addTearDown(confirmation.close);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: payment,
              child: PaymentPage(onPaid: (_) {}, onNeedsVerification: (_) {}),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('can no longer be paid'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsNothing);
        await tester.pumpWidget(
          MaterialApp(
            home: BlocProvider.value(
              value: confirmation,
              child: ConfirmationPage(
                onDone: () {},
                onResume: (_) => fail('closed order resumed'),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Back to dashboard'), findsOneWidget);
        expect(find.text('Continue your order'), findsNothing);
        expect(AppRoutes.forOrder(order), AppRoutes.confirmationFor(order.id));
      },
    );
  }

  test('failed payments resume payment and hotspot drafts bypass RICA', () {
    for (final status in [
      OrderStatus.awaitingPayment,
      OrderStatus.paymentFailed,
    ]) {
      final order = Order(
        id: 'pass',
        orderNumber: 'SC-PASS',
        planName: 'Day Pass',
        totalCents: 4900,
        status: status,
      );
      expect(AppRoutes.forOrder(order), AppRoutes.paymentFor(order.id));
    }
  });
}

String _json(Order order) => jsonEncode(order.toJson());
