import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

const _plan = Plan(
  id: 'home_100',
  name: 'Home 100',
  priceRands: 549,
  dataDescription: '100GB',
  speedMbps: 100,
  category: ProductCategory.home5g,
);
const _items = [CartItem(plan: _plan, quantity: 1)];

void main() {
  late InMemorySecureStore store;
  late SimulatedNetwork network;
  late MockCheckoutRepository repo;

  setUp(() {
    store = InMemorySecureStore();
    network = SimulatedNetwork();
    repo = MockCheckoutRepository(store, network: network, latency: Duration.zero);
  });

  Order unwrap(Either<Failure, Order> either) => either.getOrElse((_) => throw StateError('expected Right'));

  test('a new order starts pendingVerification and gets a unique number', () async {
    final a = unwrap(await repo.createOrder(items: _items));
    final b = unwrap(await repo.createOrder(items: _items));
    expect(a.status, OrderStatus.pendingVerification);
    expect(a.orderNumber, 'SEN-48213');
    expect(b.orderNumber, isNot(a.orderNumber));
    expect(a.id, isNot(b.id));
  });

  test('payment is refused until identity is verified (verify-before-charge)', () async {
    final order = unwrap(await repo.createOrder(items: _items));
    final result = await repo.pay(orderId: order.id, method: PaymentMethod.ozow);
    expect(result.isLeft(), isTrue);
    expect(unwrap(await repo.getOrder(order.id)).status, OrderStatus.pendingVerification);
  });

  test('verify then pay moves the order to paid; paying twice is idempotent', () async {
    final order = unwrap(await repo.createOrder(items: _items));
    await repo.markIdentityVerified(order.id);
    final paid = unwrap(await repo.pay(orderId: order.id, method: PaymentMethod.card));
    expect(paid.status, OrderStatus.paid);
    final again = unwrap(await repo.pay(orderId: order.id, method: PaymentMethod.card));
    expect(again, paid);
    expect((await repo.getOpenOrder()).getOrElse((_) => null), isNull);
  });

  test('a declined payment leaves the order awaitingPayment so it can be retried', () async {
    final order = unwrap(await repo.createOrder(items: _items));
    await repo.markIdentityVerified(order.id);
    repo.failNextPayment = true;
    expect((await repo.pay(orderId: order.id, method: PaymentMethod.ozow)).isLeft(), isTrue);
    expect(unwrap(await repo.getOrder(order.id)).status, OrderStatus.awaitingPayment);
    expect(unwrap(await repo.pay(orderId: order.id, method: PaymentMethod.ozow)).status, OrderStatus.paid);
  });

  test('the open order survives a restart (new repository, same store) and is superseded by a new cart', () async {
    final first = unwrap(await repo.createOrder(items: _items));
    final reopened = MockCheckoutRepository(store, network: network, latency: Duration.zero);
    expect((await reopened.getOpenOrder()).getOrElse((_) => null)?.id, first.id);

    final second = unwrap(await reopened.createOrder(items: _items));
    expect((await reopened.getOpenOrder()).getOrElse((_) => null)?.id, second.id);
    expect((await reopened.getOrder(first.id)).isLeft(), isTrue);
  });

  test('offline surfaces NetworkFailure and does not mutate anything', () async {
    network.offline = true;
    final result = await repo.createOrder(items: _items);
    expect(result.match((f) => f, (_) => null), isA<NetworkFailure>());
    network.offline = false;
    expect((await repo.getOpenOrder()).getOrElse((_) => null), isNull);
  });

  test('unknown order id is a failure, not a crash', () async {
    expect((await repo.getOrder('nope')).isLeft(), isTrue);
  });

  test('clearLocalOrders wipes persisted orders', () async {
    await repo.createOrder(items: _items);
    await repo.clearLocalOrders();
    expect(store.snapshot, isEmpty);
  });
}
