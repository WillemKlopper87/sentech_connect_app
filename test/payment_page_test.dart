import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/payment_page.dart';

import 'helpers/test_setup.dart';

const _pass = Plan(
  id: 'pass',
  name: 'Day Pass',
  priceCents: 4900,
  dataDescription: '5 GB · 1 day',
  speedMbps: 0,
  category: ProductCategory.hotspotPass,
);

const _items = [CartItem(plan: _pass, quantity: 1)];

Future<void> _pumpPage(
  WidgetTester tester,
  PaymentCubit cubit, {
  void Function(Order)? onPaid,
  bool showIdentityVerified = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      home: BlocProvider.value(
        value: cubit,
        child: PaymentPage(
          showIdentityVerified: showIdentityVerified,
          onPaid: onPaid ?? (_) {},
          onNeedsVerification: (_) {},
          onClosed: () {},
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  setUpAppTests();

  testWidgets(
    'a replayed, superseded demo order loads on the payment page (closed, no error)',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit();
      addTearDown(cart.close);
      final a = (await tester.runAsync(
        () => repo.createOrder(items: _items, idempotencyKey: 'a'),
      ))!.getOrElse((f) => throw StateError(f.message));
      await tester.runAsync(
        () => repo.createOrder(items: _items, idempotencyKey: 'b'),
      );
      final replayed = (await tester.runAsync(
        () => repo.createOrder(items: _items, idempotencyKey: 'a'),
      ))!.getOrElse((f) => throw StateError(f.message));
      expect(replayed.id, a.id);

      final cubit = PaymentCubit(repo, cart, replayed.id);
      addTearDown(cubit.close);
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _pumpPage(tester, cubit);
      expect(cubit.state.status, PaymentStatus.closed);
      expect(find.textContaining('can no longer be paid'), findsOneWidget);
      expect(find.textContaining('could not find'), findsNothing);
    },
  );

  testWidgets(
    'demo hotspot checkout: Pay hands off, polls the server order, and reports paid; never claims identity',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit()..addItem(_pass);
      addTearDown(cart.close);
      var order = (await tester.runAsync(
        () => repo.createOrder(items: _items),
      ))!.getOrElse((f) => throw StateError(f.message));
      order = (await tester.runAsync(
        () => repo.markIdentityVerified(order.id),
      ))!.getOrElse((f) => throw StateError(f.message));
      expect(order.isHotspotPass, isTrue);

      final cubit = PaymentCubit(repo, cart, order.id, wait: (_) async {});
      addTearDown(cubit.close);
      Order? paid;
      await _pumpPage(tester, cubit, onPaid: (o) => paid = o);
      expect(find.textContaining('Identity verified'), findsNothing);
      expect(find.text('Wi-Fi pass order'), findsOneWidget);

      await tester.tap(find.textContaining('Pay '));
      await tester.pumpAndSettle();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(paid?.id, order.id);
      expect(cart.state.items, isEmpty);
    },
  );

  testWidgets(
    'a still-pending payment offers Check again and Pay again (no false success)',
    (tester) async {
      final repo = MockCheckoutRepository(
        InMemorySecureStore(),
        latency: Duration.zero,
      );
      final cart = CartCubit()..addItem(_pass);
      addTearDown(cart.close);
      final order = (await tester.runAsync(
        () => repo.createOrder(items: _items),
      ))!.getOrElse((f) => throw StateError(f.message));
      await tester.runAsync(() => repo.markIdentityVerified(order.id));
      // No poll ever sees the order paid: the schedule is empty.
      final cubit = PaymentCubit(repo, cart, order.id, pollDelays: const []);
      addTearDown(cubit.close);
      await _pumpPage(tester, cubit);
      await tester.tap(find.textContaining('Pay '));
      await tester.pumpAndSettle();
      expect(cubit.state.status, PaymentStatus.stillPending);
      expect(find.text('Check again'), findsOneWidget);
      expect(find.text('Pay again'), findsOneWidget);
      expect(cart.state.items, isNotEmpty);
    },
  );
}
