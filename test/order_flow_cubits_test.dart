import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/mock_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
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
    repo = MockCheckoutRepository(InMemorySecureStore(), network: network, latency: Duration.zero);
    cart = CartCubit()..addItem(_plan);
  });

  tearDown(() => cart.close());

  Future<Order> newOrder() async =>
      (await repo.createOrder(items: cart.state.items)).getOrElse((_) => throw StateError('create failed'));

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
        isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.creating),
        isA<CheckoutState>().having((s) => s.failure, 'failure', isA<NetworkFailure>()),
        isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.creating),
        isA<CheckoutState>().having((s) => s.status, 'status', CheckoutStatus.created),
      ],
    );
  });

  group('RicaCubit', () {
    test('a failed liveness check keeps the order pending; retry then verifies it', () async {
      final order = await newOrder();
      final rica = RicaCubit(
        _ScriptedLiveness([const Right(false), const Right(true)]),
        repo,
        order.id,
      );
      await rica.verify();
      expect(rica.state.status, RicaStatus.failure);
      expect(rica.state.failureReason, RicaFailureReason.notVerified);
      expect((await repo.getOrder(order.id)).getOrElse((_) => order).status, OrderStatus.pendingVerification);

      await rica.verify();
      expect(rica.state.status, RicaStatus.verified);
      expect((await repo.getOrder(order.id)).getOrElse((_) => order).status, OrderStatus.awaitingPayment);
      await rica.close();
    });

    test('a vendor error (Left) is treated as not verified', () async {
      final order = await newOrder();
      final rica = RicaCubit(_ScriptedLiveness([const Left(ServerFailure())]), repo, order.id);
      await rica.verify();
      expect(rica.state.status, RicaStatus.failure);
      await rica.close();
    });

    test('losing the network after a passed check reports a network failure', () async {
      final order = await newOrder();
      final rica = RicaCubit(_ScriptedLiveness([const Right(true)]), repo, order.id);
      network.offline = true;
      await rica.verify();
      expect(rica.state.failureReason, RicaFailureReason.network);
      await rica.close();
    });
  });

  group('PaymentCubit', () {
    test('an order still pending verification cannot be paid from the payment screen', () async {
      final order = await newOrder();
      final payment = PaymentCubit(repo, cart, order.id);
      await Future<void>.delayed(Duration.zero);
      expect(payment.state.status, PaymentStatus.needsVerification);
      await payment.close();
    });

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
      expect(payment.state.status, PaymentStatus.paid);
      expect(cart.state.items, isEmpty);
      await payment.close();
    });

    test('an unknown order id reports loadFailed instead of throwing', () async {
      final payment = PaymentCubit(repo, cart, 'missing');
      await Future<void>.delayed(Duration.zero);
      expect(payment.state.status, PaymentStatus.loadFailed);
      await payment.close();
    });
  });
}
