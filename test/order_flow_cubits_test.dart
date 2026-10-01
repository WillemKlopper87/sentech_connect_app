import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/checkout_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';
import 'package:sentech_connect_app/features/rica/domain/repositories/liveness_repository.dart';
import 'package:sentech_connect_app/features/rica/presentation/bloc/rica_cubit.dart';

const _plan = Plan(
  id: 'home_100',
  name: 'Home 100',
  priceCents: 54900,
  dataDescription: '100GB',
  speedMbps: 100,
  category: ProductCategory.home5g,
);

class _ScriptedLiveness implements LivenessRepository {
  _ScriptedLiveness(this.results);

  final List<Either<Failure, bool>> results;

  @override
  Future<Either<Failure, bool>> verifyLiveness() async => results.removeAt(0);
}

void main() {
  late SimulatedNetwork network;
  late MockCheckoutRepository repo;
  late CartCubit cart;

  setUp(() {
    network = SimulatedNetwork();
    repo = MockCheckoutRepository(
      InMemorySecureStore(),
      network: network,
      latency: Duration.zero,
    );
    cart = CartCubit()..addItem(_plan);
  });

  tearDown(() => cart.close());

  Future<Order> newOrder() async => (await repo.createOrder(
    items: cart.state.items,
  )).getOrElse((_) => throw StateError('create failed'));

  group('CheckoutCubit idempotency', () {
    test(
      'a retry after a failure reuses the SAME key (no second order for one cart)',
      () async {
        final keys = <String?>[];
        final recording = _KeyRecordingCheckout(repo, keys);
        var n = 0;
        final cubit = CheckoutCubit(
          recording,
          cart,
          newKey: () => 'app-key-${n++}',
        );
        network.offline = true;
        await cubit.createOrder();
        network.offline = false;
        await cubit.createOrder();
        expect(keys, ['app-key-0', 'app-key-0']);
        expect(cubit.state.status, CheckoutStatus.created);
        await cubit.close();
      },
    );

    test('a new checkout (new cart review) gets a new key', () async {
      final keys = <String?>[];
      var n = 0;
      String key() => 'app-key-${n++}';
      final first = CheckoutCubit(
        _KeyRecordingCheckout(repo, keys),
        cart,
        newKey: key,
      );
      await first.createOrder();
      final second = CheckoutCubit(
        _KeyRecordingCheckout(repo, keys),
        cart,
        newKey: key,
      );
      await second.createOrder();
      expect(keys.toSet(), hasLength(2));
      await first.close();
      await second.close();
    });

    test('the demo repository honours the key like the server does', () async {
      final a = (await repo.createOrder(
        items: cart.state.items,
        idempotencyKey: 'app-same',
      )).getOrElse((_) => throw StateError('a'));
      final b = (await repo.createOrder(
        items: cart.state.items,
        idempotencyKey: 'app-same',
      )).getOrElse((_) => throw StateError('b'));
      expect(b.id, a.id);
    });
  });

  test(
    'demo A/B/A replays the original creation snapshot after supersession',
    () async {
      final a = (await repo.createOrder(
        items: cart.state.items,
        idempotencyKey: 'A',
      )).getOrElse((f) => throw StateError(f.message));
      final b = (await repo.createOrder(
        items: cart.state.items,
        idempotencyKey: 'B',
      )).getOrElse((f) => throw StateError(f.message));
      final replay = (await repo.createOrder(
        items: cart.state.items,
        idempotencyKey: 'A',
      )).getOrElse((f) => throw StateError(f.message));
      expect(replay, a);
      expect(
        (await repo.getOpenOrder()).getOrElse(
          (f) => throw StateError(f.message),
        ),
        b,
      );
      await repo.clearLocalOrders();
      final fresh = (await repo.createOrder(
        items: cart.state.items,
        idempotencyKey: 'A',
      )).getOrElse((f) => throw StateError(f.message));
      expect(fresh.id, isNot(a.id));
    },
  );

  test('concurrent same-key demo requests create just one order', () async {
    final results = await Future.wait(
      List.generate(
        4,
        (_) => repo.createOrder(
          items: cart.state.items,
          idempotencyKey: 'parallel',
        ),
      ),
    );
    final orders = results
        .map((r) => r.getOrElse((f) => throw StateError(f.message)))
        .toList();
    expect(orders.map((o) => o.id).toSet(), hasLength(1));
  });

  group('server order state', () {
    for (final status in [OrderStatus.expired, OrderStatus.cancelled]) {
      test('$status cannot reach a payment mutation', () async {
        final order = (await newOrder()).copyWith(status: status);
        final scripted = _StateCheckout(repo, order);
        final cubit = PaymentCubit(scripted, cart, order.id);
        await Future<void>.delayed(Duration.zero);
        expect(cubit.state.status, PaymentStatus.closed);
        await cubit.pay();
        expect(scripted.payCalls, 0);
        expect(cubit.state.status, PaymentStatus.closed);
        expect(cart.state.items, isNotEmpty);
        await cubit.close();
      });
    }

    test(
      'an unpaid server response never claims paid or clears the cart',
      () async {
        final order = (await newOrder()).copyWith(
          status: OrderStatus.awaitingPayment,
        );
        final scripted = _StateCheckout(repo, order);
        final cubit = PaymentCubit(
          scripted,
          cart,
          order.id,
          pollDelays: const [Duration.zero],
        );
        await Future<void>.delayed(Duration.zero);
        await cubit.pay();
        expect(cubit.state.status, PaymentStatus.handoff);
        await cubit.handoffFinished();
        expect(cubit.state.status, PaymentStatus.stillPending);
        expect(cart.state.items, isNotEmpty);
        await cubit.close();
      },
    );
  });

  group('CheckoutCubit', () {
    blocTest<CheckoutCubit, CheckoutState>(
      'creates the order (unpaid) and leaves the cart untouched until payment',
      build: () => CheckoutCubit(repo, cart),
      act: (c) => c.createOrder(),
      verify: (c) {
        expect(c.state.status, CheckoutStatus.created);
        expect(c.state.order?.status, OrderStatus.pendingVerification);
        expect(cart.state.items, isNotEmpty);
      },
    );

    blocTest<CheckoutCubit, CheckoutState>(
      'offline creation fails with a NetworkFailure that can be retried',
      build: () {
        network.offline = true;
        return CheckoutCubit(repo, cart);
      },
      act: (c) async {
        await c.createOrder();
        network.offline = false;
        await c.createOrder();
      },
      verify: (c) => expect(c.state.status, CheckoutStatus.created),
      expect: () => [
        isA<CheckoutState>().having(
          (s) => s.status,
          'status',
          CheckoutStatus.creating,
        ),
        isA<CheckoutState>().having(
          (s) => s.failure,
          'failure',
          isA<NetworkFailure>(),
        ),
        isA<CheckoutState>().having(
          (s) => s.status,
          'status',
          CheckoutStatus.creating,
        ),
        isA<CheckoutState>().having(
          (s) => s.status,
          'status',
          CheckoutStatus.created,
        ),
      ],
    );
  });

  group('RicaCubit', () {
    test(
      'a failed liveness check keeps the order pending; retry then verifies it',
      () async {
        final order = await newOrder();
        final rica = RicaCubit(
          _ScriptedLiveness([const Right(false), const Right(true)]),
          repo,
          order.id,
        );
        await rica.verify();
        expect(rica.state.status, RicaStatus.failure);
        expect(rica.state.failureReason, RicaFailureReason.notVerified);
        expect(
          (await repo.getOrder(order.id)).getOrElse((_) => order).status,
          OrderStatus.pendingVerification,
        );

        await rica.verify();
        expect(rica.state.status, RicaStatus.verified);
        expect(
          (await repo.getOrder(order.id)).getOrElse((_) => order).status,
          OrderStatus.awaitingPayment,
        );
        await rica.close();
      },
    );

    test('a vendor error (Left) is treated as not verified', () async {
      final order = await newOrder();
      final rica = RicaCubit(
        _ScriptedLiveness([const Left(ServerFailure())]),
        repo,
        order.id,
      );
      await rica.verify();
      expect(rica.state.status, RicaStatus.failure);
      await rica.close();
    });

    test(
      'losing the network after a passed check reports a network failure',
      () async {
        final order = await newOrder();
        final rica = RicaCubit(
          _ScriptedLiveness([const Right(true)]),
          repo,
          order.id,
        );
        network.offline = true;
        await rica.verify();
        expect(rica.state.failureReason, RicaFailureReason.network);
        await rica.close();
      },
    );
  });

  group('PaymentCubit', () {
    test(
      'an order still pending verification cannot be paid from the payment screen',
      () async {
        final order = await newOrder();
        final payment = PaymentCubit(repo, cart, order.id);
        await Future<void>.delayed(Duration.zero);
        expect(payment.state.status, PaymentStatus.needsVerification);
        await payment.close();
      },
    );

    test('decline -> retry -> paid clears the cart only on success', () async {
      final order = await newOrder();
      await repo.markIdentityVerified(order.id);
      final payment = PaymentCubit(repo, cart, order.id);
      await Future<void>.delayed(Duration.zero);
      expect(payment.state.status, PaymentStatus.ready);

      repo.failNextPayment = true;
      await payment.pay();
      expect(payment.state.status, PaymentStatus.payFailed);
      expect(cart.state.items, isNotEmpty);

      await payment.pay();
      expect(payment.state.status, PaymentStatus.handoff);
      await payment.handoffFinished();
      expect(payment.state.status, PaymentStatus.paid);
      expect(cart.state.items, isEmpty);
      await payment.close();
    });

    test(
      'an unknown order id reports loadFailed instead of throwing',
      () async {
        final payment = PaymentCubit(repo, cart, 'missing');
        await Future<void>.delayed(Duration.zero);
        expect(payment.state.status, PaymentStatus.loadFailed);
        await payment.close();
      },
    );
  });
}

class _KeyRecordingCheckout implements CheckoutRepository {
  _KeyRecordingCheckout(this._inner, this.keys);

  final CheckoutRepository _inner;
  final List<String?> keys;

  @override
  Future<Either<Failure, Order>> createOrder({
    required List<CartItem> items,
    String? idempotencyKey,
  }) {
    keys.add(idempotencyKey);
    return _inner.createOrder(items: items, idempotencyKey: idempotencyKey);
  }

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) =>
      _inner.getOrder(orderId);

  @override
  Future<Either<Failure, Order?>> getOpenOrder() => _inner.getOpenOrder();

  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) =>
      _inner.markIdentityVerified(orderId);

  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({
    required String orderId,
  }) => _inner.startPayment(orderId: orderId);

  @override
  Future<void> clearLocalOrders() => _inner.clearLocalOrders();
}

class _StateCheckout extends _KeyRecordingCheckout {
  _StateCheckout(CheckoutRepository inner, this.order) : super(inner, []);
  final Order order;
  int payCalls = 0;

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) async => Right(order);

  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({
    required String orderId,
  }) async {
    payCalls++;
    return Right(
      PaymentHandoff(
        paymentId: 'pay-scripted',
        reference: order.orderNumber,
        gateway: PaymentHandoff.demoGateway,
        method: PaymentHandoffMethod.get,
        url: Uri.parse('about:blank'),
        amountCents: order.totalCents,
      ),
    );
  }
}
