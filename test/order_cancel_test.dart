import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/pages/payment_page.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _orderId = '5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f10';

const _pass = Plan(
  id: 'pass',
  name: 'Day Pass',
  priceCents: 4900,
  dataDescription: '5 GB · 1 day',
  speedMbps: 0,
  category: ProductCategory.hotspotPass,
);

/// Serves [orders] one per `getOrder` call (the last repeats); `cancelOrder`
/// answers [cancelResult].
class _FakeCheckout implements CheckoutRepository {
  _FakeCheckout(this.orders, {this.cancelResult});

  final List<Order> orders;
  Either<Failure, Order>? cancelResult;
  int getCalls = 0;
  int cancelCalls = 0;

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) async =>
      Right(orders[getCalls < orders.length ? getCalls++ : orders.length - 1]);

  @override
  Future<Either<Failure, Order>> cancelOrder(String orderId) async {
    cancelCalls++;
    return cancelResult!;
  }

  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({required String orderId}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items, String? idempotencyKey}) =>
      throw UnimplementedError();

  @override
  Future<Either<Failure, Order?>> getOpenOrder() => throw UnimplementedError();

  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) => throw UnimplementedError();

  @override
  Future<void> clearLocalOrders() async {}
}

Order _order(OrderStatus status) => Order(
  id: 'o1',
  orderNumber: 'SC-O1',
  planName: 'Day Pass',
  totalCents: 4900,
  status: status,
  isHotspotPass: true,
);

void main() {
  group('HttpCheckoutRepository.cancelOrder', () {
    late ApiHarness h;
    late HttpCheckoutRepository repo;

    setUp(() async {
      h = ApiHarness();
      repo = HttpCheckoutRepository(h.api);
      await h.signIn();
    });

    test('posts to the cancel route and returns the order as the server now holds it', () async {
      h.adapter.on(
        'POST',
        '/v1/orders/$_orderId/cancel',
        (_) => FakeReply(200, {...fixtureMap('order_draft.json'), 'status': 'cancelled'}),
      );
      final order = (await repo.cancelOrder(_orderId)).getOrElse((f) => throw StateError(f.message));
      expect(order.status, OrderStatus.cancelled);
      expect(order.isOpen, isFalse);
      expect(h.adapter.requestsTo('POST', '/v1/orders/$_orderId/cancel'), hasLength(1));
    });

    test('409 order_not_cancellable (for example already paid) is typed', () async {
      h.adapter.on('POST', '/v1/orders/$_orderId/cancel', (_) => FakeReply.problem(409, 'order_not_cancellable'));
      expect((await repo.cancelOrder(_orderId)).match((f) => f, (_) => null), isA<OrderNotCancellableFailure>());
    });

    test('409 order_cancelled is typed', () async {
      h.adapter.on('POST', '/v1/orders/$_orderId/cancel', (_) => FakeReply.problem(409, 'order_cancelled'));
      expect((await repo.cancelOrder(_orderId)).match((f) => f, (_) => null), isA<OrderCancelledFailure>());
    });

    test('404 order_not_found is typed', () async {
      h.adapter.on('POST', '/v1/orders/$_orderId/cancel', (_) => FakeReply.problem(404, 'order_not_found'));
      expect((await repo.cancelOrder(_orderId)).match((f) => f, (_) => null), isA<OrderNotFoundFailure>());
    });

    test('offline is a NetworkFailure', () async {
      h.adapter.on(
        'POST',
        '/v1/orders/$_orderId/cancel',
        (_) => const FakeReply.error(DioExceptionType.connectionError),
      );
      expect((await repo.cancelOrder(_orderId)).match((f) => f, (_) => null), isA<NetworkFailure>());
    });
  });

  group('MockCheckoutRepository.cancelOrder', () {
    late MockCheckoutRepository repo;

    setUp(() => repo = MockCheckoutRepository(InMemorySecureStore(), latency: Duration.zero));

    Future<Order> create() async => (await repo.createOrder(
      items: const [CartItem(plan: _pass, quantity: 1)],
    )).getOrElse((f) => throw StateError(f.message));

    test('cancels an open order, once', () async {
      final order = await create();
      final cancelled = (await repo.cancelOrder(order.id)).getOrElse((f) => throw StateError(f.message));
      expect(cancelled.status, OrderStatus.cancelled);
      expect((await repo.getOpenOrder()).getOrElse((_) => null), isNull);
      expect((await repo.cancelOrder(order.id)).match((f) => f, (_) => null), isA<OrderCancelledFailure>());
    });

    test('a paid order cannot be cancelled', () async {
      final order = await create();
      await repo.startPayment(orderId: order.id);
      expect((await repo.cancelOrder(order.id)).match((f) => f, (_) => null), isA<OrderNotCancellableFailure>());
    });

    test('an unknown order is not found', () async {
      expect((await repo.cancelOrder('nope')).match((f) => f, (_) => null), isA<OrderNotFoundFailure>());
    });
  });

  group('PaymentCubit.cancel', () {
    late CartCubit cart;
    setUp(() => cart = CartCubit());
    tearDown(() => cart.close());

    Future<PaymentCubit> open(_FakeCheckout repo) async {
      final cubit = PaymentCubit(repo, cart, 'o1');
      addTearDown(cubit.close);
      await Future<void>.delayed(Duration.zero);
      return cubit;
    }

    test('success closes the order as cancelled', () async {
      final repo = _FakeCheckout([_order(OrderStatus.awaitingPayment)], cancelResult: Right(_order(OrderStatus.cancelled)));
      final cubit = await open(repo);
      expect(cubit.state.canCancel, isTrue);
      await cubit.cancel();
      expect(cubit.state.status, PaymentStatus.closed);
      expect(cubit.state.order!.status, OrderStatus.cancelled);
      expect(cubit.state.canCancel, isFalse);
      expect(repo.cancelCalls, 1);
    });

    test('a failed payment can be cancelled too', () async {
      final repo = _FakeCheckout([_order(OrderStatus.paymentFailed)], cancelResult: Right(_order(OrderStatus.cancelled)));
      final cubit = await open(repo);
      expect(cubit.state.canCancel, isTrue);
      await cubit.cancel();
      expect(cubit.state.status, PaymentStatus.closed);
    });

    test('a paid order offers no cancel and cancel() does nothing', () async {
      final repo = _FakeCheckout([_order(OrderStatus.paid)], cancelResult: Right(_order(OrderStatus.cancelled)));
      final cubit = await open(repo);
      expect(cubit.state.status, PaymentStatus.paid);
      expect(cubit.state.canCancel, isFalse);
      await cubit.cancel();
      expect(repo.cancelCalls, 0);
      expect(cubit.state.status, PaymentStatus.paid);
    });

    test('order_not_cancellable because it was paid meanwhile: reload shows paid and says why', () async {
      final repo = _FakeCheckout(
        [_order(OrderStatus.awaitingPayment), _order(OrderStatus.paid)],
        cancelResult: const Left(OrderNotCancellableFailure()),
      );
      final cubit = await open(repo);
      await cubit.cancel();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(cubit.state.cancelFailure, isA<OrderNotCancellableFailure>());
    });

    test('order_cancelled: reload shows the cancelled order as closed', () async {
      final repo = _FakeCheckout(
        [_order(OrderStatus.awaitingPayment), _order(OrderStatus.cancelled)],
        cancelResult: const Left(OrderCancelledFailure()),
      );
      final cubit = await open(repo);
      await cubit.cancel();
      expect(cubit.state.status, PaymentStatus.closed);
      expect(cubit.state.cancelFailure, isA<OrderCancelledFailure>());
    });

    test('order_not_found ends on a load failure with the typed failure', () async {
      final repo = _FakeCheckout(
        [_order(OrderStatus.awaitingPayment)],
        cancelResult: const Left(OrderNotFoundFailure()),
      );
      final cubit = await open(repo);
      await cubit.cancel();
      expect(cubit.state.status, PaymentStatus.loadFailed);
      expect(cubit.state.failure, isA<OrderNotFoundFailure>());
    });

    test('offline keeps the order payable and reports the failure', () async {
      final repo = _FakeCheckout(
        [_order(OrderStatus.awaitingPayment)],
        cancelResult: const Left(NetworkFailure()),
      );
      final cubit = await open(repo);
      await cubit.cancel();
      expect(cubit.state.status, PaymentStatus.ready);
      expect(cubit.state.canCancel, isTrue);
      expect(cubit.state.cancelFailure, isA<NetworkFailure>());
    });
  });

  group('PaymentPage cancel', () {
    late CartCubit cart;
    setUp(() => cart = CartCubit());
    tearDown(() => cart.close());

    final l10n = lookupAppLocalizations(const Locale('en'));

    Future<_FakeCheckout> pump(WidgetTester tester, _FakeCheckout repo) async {
      final cubit = PaymentCubit(repo, cart, 'o1');
      addTearDown(cubit.close);
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider.value(
            value: cubit,
            child: PaymentPage(onPaid: (_) {}, onNeedsVerification: (_) {}, onClosed: () {}),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return repo;
    }

    testWidgets('an unpaid order offers Cancel; Keep leaves it alone', (tester) async {
      final repo = await pump(tester, _FakeCheckout([_order(OrderStatus.awaitingPayment)], cancelResult: Right(_order(OrderStatus.cancelled))));
      await tester.tap(find.byKey(const ValueKey('cancel-order')));
      await tester.pumpAndSettle();
      expect(find.text(l10n.orderCancelConfirmTitle), findsOneWidget);
      await tester.tap(find.text(l10n.orderCancelKeep));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls, 0);
      expect(find.byKey(const ValueKey('cancel-order')), findsOneWidget);
    });

    testWidgets('confirming cancels and shows the cancelled message', (tester) async {
      final repo = await pump(tester, _FakeCheckout([_order(OrderStatus.awaitingPayment)], cancelResult: Right(_order(OrderStatus.cancelled))));
      await tester.tap(find.byKey(const ValueKey('cancel-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.orderCancelAction)));
      await tester.pumpAndSettle();
      expect(repo.cancelCalls, 1);
      expect(find.text(l10n.paymentClosedCancelled), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-order')), findsNothing);
    });

    testWidgets('a refusal shows its typed message and keeps the order visible', (tester) async {
      await pump(
        tester,
        _FakeCheckout(
          [_order(OrderStatus.awaitingPayment), _order(OrderStatus.awaitingPayment)],
          cancelResult: const Left(OrderNotCancellableFailure()),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('cancel-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.orderCancelAction)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.failureOrderNotCancellable), findsOneWidget);
    });

    testWidgets('offline shows the offline message', (tester) async {
      await pump(tester, _FakeCheckout([_order(OrderStatus.awaitingPayment)], cancelResult: const Left(NetworkFailure())));
      await tester.tap(find.byKey(const ValueKey('cancel-order')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(l10n.orderCancelAction)));
      await tester.pumpAndSettle();
      expect(find.text(l10n.failureYouReOfflineCheckYourConnection), findsOneWidget);
      expect(find.byKey(const ValueKey('cancel-order')), findsOneWidget);
    });

    testWidgets('a paid order does not offer Cancel', (tester) async {
      await pump(tester, _FakeCheckout([_order(OrderStatus.paid)], cancelResult: Right(_order(OrderStatus.cancelled))));
      expect(find.byKey(const ValueKey('cancel-order')), findsNothing);
    });
  });
}
