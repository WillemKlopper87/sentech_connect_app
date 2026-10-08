import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart';

const _pass = Plan(
  id: 'p',
  name: '1 Hour Pass',
  priceCents: 1500,
  dataDescription: '1 GB · 1 hour',
  speedMbps: 10,
  category: ProductCategory.hotspotPass,
);

final _handoff = PaymentHandoff(
  paymentId: 'pay1',
  reference: 'SC1',
  gateway: 'netcash',
  method: PaymentHandoffMethod.post,
  url: Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx'),
  amountCents: 1500,
);

/// Load returns [loadStatus]; each poll takes the next scripted reply.
class _ScriptedCheckout implements CheckoutRepository {
  _ScriptedCheckout({
    this.loadStatus = OrderStatus.awaitingPayment,
    List<Either<Failure, OrderStatus>>? polls,
  }) : polls = polls ?? [];

  final OrderStatus loadStatus;
  final List<Either<Failure, OrderStatus>> polls;
  int getCalls = 0;
  int startCalls = 0;
  Completer<void>? startGate;
  Either<Failure, PaymentHandoff>? startResult;

  Order _order(OrderStatus s) => Order(
    id: 'o1',
    orderNumber: 'SC-O1',
    planName: '1 Hour Pass',
    totalCents: 1500,
    status: s,
    isHotspotPass: true,
  );

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) async {
    getCalls++;
    if (getCalls == 1) return Right(_order(loadStatus));
    final next = polls.isEmpty
        ? const Right<Failure, OrderStatus>(OrderStatus.awaitingPayment)
        : polls.removeAt(0);
    return next.map(_order);
  }

  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({
    required String orderId,
  }) async {
    startCalls++;
    await startGate?.future;
    return startResult ?? Right(_handoff);
  }

  @override
  Future<Either<Failure, Order>> createOrder({
    required List<CartItem> items,
    String? idempotencyKey,
  }) => throw UnimplementedError();

  @override
  Future<Either<Failure, Order?>> getOpenOrder() => throw UnimplementedError();

  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) =>
      throw UnimplementedError();

  @override
  Future<void> clearLocalOrders() async {}
}

void main() {
  late CartCubit cart;
  late List<Duration> waits;

  setUp(() {
    cart = CartCubit()..addItem(_pass);
    waits = [];
  });

  tearDown(() => cart.close());

  Future<PaymentCubit> ready(
    _ScriptedCheckout repo, {
    List<Duration> delays = defaultPollDelays,
    Future<void> Function(Duration)? wait,
  }) async {
    cart.bindCheckoutOrder('o1', cart.state.items, source: cart.state);
    final cubit = PaymentCubit(
      repo,
      cart,
      'o1',
      pollDelays: delays,
      wait: wait ?? (d) async => waits.add(d),
    );
    await Future<void>.delayed(Duration.zero);
    return cubit;
  }

  test(
    'polls until the server marks the order paid, then clears the cart',
    () async {
      final repo = _ScriptedCheckout(
        polls: [
          const Right(OrderStatus.awaitingPayment),
          const Right(OrderStatus.awaitingPayment),
          const Right(OrderStatus.paid),
        ],
      );
      final cubit = await ready(repo);
      await cubit.pay();
      expect(cubit.state.status, PaymentStatus.handoff);
      expect(cubit.state.handoff, _handoff);
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(repo.getCalls, 1 + 3);
      expect(waits, defaultPollDelays.take(3).toList());
      expect(cart.state.items, isEmpty);
      await cubit.close();
    },
  );

  test(
    'a provider that collects its own money closes the order without a retry loop',
    () async {
      final repo = _ScriptedCheckout()
        ..startResult = const Left(CollectionExternalFailure());
      final cubit = await ready(repo);
      await cubit.pay();
      expect(cubit.state.status, PaymentStatus.closed);
      expect(cubit.state.failure, const CollectionExternalFailure());
      expect(repo.startCalls, 1);
      await cubit.pay(); // closed is final: no second call to the server
      expect(repo.startCalls, 1);
      await cubit.close();
    },
  );

  test(
    'a declined payment ends polling with a retryable failure and keeps the cart',
    () async {
      final repo = _ScriptedCheckout(
        polls: [const Right(OrderStatus.paymentFailed)],
      );
      final cubit = await ready(repo);
      await cubit.pay();
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.payFailed);
      expect(
        (cubit.state.failure! as ValidationFailure).code,
        'payment_failed',
      );
      expect(cart.state.items, isNotEmpty);
      await cubit.close();
    },
  );

  test(
    'polling is bounded: no confirmation within the schedule -> stillPending, then silence',
    () async {
      final repo = _ScriptedCheckout();
      final cubit = await ready(
        repo,
        delays: const [Duration.zero, Duration.zero, Duration.zero],
      );
      await cubit.pay();
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.stillPending);
      expect(repo.getCalls, 1 + 3);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(repo.getCalls, 1 + 3);

      repo.polls.add(const Right(OrderStatus.paid));
      await cubit.checkAgain();
      expect(cubit.state.status, PaymentStatus.paid);
      await cubit.close();
    },
  );

  test('offline blips while polling are tolerated', () async {
    final repo = _ScriptedCheckout(
      polls: [const Left(NetworkFailure()), const Right(OrderStatus.paid)],
    );
    final cubit = await ready(repo);
    await cubit.pay();
    await cubit.handoffFinished();
    expect(cubit.state.status, PaymentStatus.paid);
    await cubit.close();
  });

  test('closing the screen stops polling', () async {
    final repo = _ScriptedCheckout();
    final gate = Completer<void>();
    final cubit = await ready(repo, wait: (_) => gate.future);
    await cubit.pay();
    final polling = cubit.handoffFinished();
    await cubit.close();
    gate.complete();
    await polling;
    expect(repo.getCalls, 1);
  });

  test('double-tapping Pay starts ONE payment attempt', () async {
    final repo = _ScriptedCheckout()..startGate = Completer<void>();
    final cubit = await ready(repo);
    final first = cubit.pay();
    final second = cubit.pay();
    repo.startGate!.complete();
    await Future.wait([first, second]);
    expect(repo.startCalls, 1);
    await cubit.close();
  });

  test(
    'stillPending -> late paid -> Pay again -> 409 not payable -> reloads and shows paid',
    () async {
      final repo = _ScriptedCheckout();
      final cubit = await ready(repo, delays: const [Duration.zero]);
      await cubit.pay();
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.stillPending);

      repo.startResult = const Left(
        ValidationFailure(
          'An order that is paid cannot be paid.',
          'order_not_payable',
        ),
      );
      repo.polls.add(const Right(OrderStatus.paid));
      await cubit.pay();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(cart.state.items, isEmpty);
      await cubit.close();
    },
  );

  test(
    '409 not payable on an expired / cancelled order routes to closed',
    () async {
      for (final status in [OrderStatus.expired, OrderStatus.cancelled]) {
        final repo = _ScriptedCheckout();
        final cubit = await ready(repo, delays: const [Duration.zero]);
        repo.startResult = const Left(
          ValidationFailure('Not payable.', 'order_not_payable'),
        );
        repo.polls.add(Right(status));
        await cubit.pay();
        expect(cubit.state.status, PaymentStatus.closed);
        expect(cubit.state.order!.status, status);
        await cubit.close();
      }
    },
  );

  test('409 not payable but still awaiting payment shows the error', () async {
    final repo = _ScriptedCheckout()
      ..startResult = const Left(
        ValidationFailure('Not payable.', 'order_not_payable'),
      );
    final cubit = await ready(repo);
    await cubit.pay();
    expect(cubit.state.status, PaymentStatus.payFailed);
    await cubit.close();
  });

  test('an unsafe hand-off URL is a hand-off failure, never opened', () async {
    final repo = _ScriptedCheckout()
      ..startResult = Right(
        PaymentHandoff(
          paymentId: 'p',
          reference: 'r',
          gateway: 'netcash',
          method: PaymentHandoffMethod.get,
          url: Uri.parse('http://evil.example/pay'),
          amountCents: 1500,
        ),
      );
    final cubit = await ready(repo);
    await cubit.pay();
    expect(cubit.state.status, PaymentStatus.payFailed);
    expect(
      (cubit.state.failure! as ValidationFailure).code,
      PaymentCubit.handoffInvalidCode,
    );
    await cubit.close();
  });

  test('closing the cubit while the hand-off is open does not throw', () async {
    final repo = _ScriptedCheckout();
    final cubit = await ready(repo);
    await cubit.pay();
    await cubit.close();
    await cubit.handoffFinished(); // page returns after the screen is gone
    await cubit.checkAgain();
    expect(repo.getCalls, 1);
  });

  test('an expired order is reported as closed, not payable', () async {
    final cubit = await ready(
      _ScriptedCheckout(loadStatus: OrderStatus.expired),
    );
    expect(cubit.state.status, PaymentStatus.closed);
    await cubit.close();
  });

  test(
    'an order whose last payment failed opens ready to retry, with the reason',
    () async {
      final cubit = await ready(
        _ScriptedCheckout(loadStatus: OrderStatus.paymentFailed),
      );
      expect(cubit.state.status, PaymentStatus.payFailed);
      await cubit.close();
    },
  );

  test(
    'a late payment can still fulfil an expired order: polling continues past expired',
    () async {
      final repo = _ScriptedCheckout(
        polls: [
          const Right(OrderStatus.expired),
          const Right(OrderStatus.paid),
        ],
      );
      final cubit = await ready(repo);
      await cubit.pay();
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.paid);
      expect(cart.state.items, isEmpty);
      await cubit.close();
    },
  );

  test(
    'still expired/cancelled when the window ends -> closed (not payable)',
    () async {
      final repo = _ScriptedCheckout(
        polls: [
          const Right(OrderStatus.cancelled),
          const Right(OrderStatus.cancelled),
        ],
      );
      final cubit = await ready(
        repo,
        delays: const [Duration.zero, Duration.zero],
      );
      await cubit.pay();
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.closed);
      await cubit.close();
    },
  );

  test(
    'a return URL alone never marks paid: handoffFinished only polls the server',
    () async {
      final repo = _ScriptedCheckout();
      final cubit = await ready(repo, delays: const [Duration.zero]);
      await cubit.pay();
      await cubit.handoffFinished();
      expect(cubit.state.status, PaymentStatus.stillPending);
      expect(cart.state.items, isNotEmpty);
      await cubit.close();
    },
  );
}
