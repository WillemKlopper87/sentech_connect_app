import 'dart:convert';

import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/simulated_network.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

/// Mock order service that still behaves like the real thing where it
/// matters to the app: orders are persisted (so the flow is resumable),
/// order numbers are unique, payment requires a verified identity and is
/// idempotent. A backend implementation replaces this class only.
class MockCheckoutRepository implements CheckoutRepository {
  MockCheckoutRepository(this._store, {SimulatedNetwork? network, this._latency = const Duration(milliseconds: 900)})
      : _network = network ?? SimulatedNetwork();

  static const _ordersKey = 'orders';
  static const _counterKey = 'order_counter';
  static const _firstOrderNumber = 48213;

  final SecureStore _store;
  final SimulatedNetwork _network;
  final Duration _latency;

  /// Test hook: makes the next `pay` call fail once (provider declined).
  bool failNextPayment = false;

  Future<List<Order>> _load() async {
    final raw = await _store.read(_ordersKey);
    if (raw == null) return [];
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } catch (_) {
      return [];
    }
    if (decoded is! List) return [];
    // Skip only a corrupt record; the customer's valid orders around it stay.
    final orders = <Order>[];
    for (final entry in decoded) {
      try {
        orders.add(Order.fromJson(entry as Map<String, dynamic>));
      } catch (_) {
        continue;
      }
    }
    return orders;
  }

  Future<void> _save(List<Order> orders) =>
      _store.write(_ordersKey, jsonEncode(orders.map((o) => o.toJson()).toList()));

  Future<int> _nextCounter() async {
    final current = int.tryParse(await _store.read(_counterKey) ?? '') ?? 0;
    await _store.write(_counterKey, '${current + 1}');
    return current;
  }

  @override
  Future<Either<Failure, Order>> createOrder({required List<CartItem> items}) async {
    await Future.delayed(_latency ~/ 3);
    if (_network.failure case final failure?) return Left(failure);
    if (items.isEmpty) return const Left(ValidationFailure('Your cart is empty.'));

    final n = await _nextCounter();
    final total = items.fold(0, (sum, i) => sum + i.lineTotalCents);
    final summary = items.length == 1 ? items.first.plan.name : '${items.length} items';
    final order = Order(
      id: 'ord_${DateTime.now().microsecondsSinceEpoch}_$n',
      orderNumber: 'SEN-${_firstOrderNumber + n}',
      planName: summary,
      totalCents: total,
    );
    // One open order at a time: a new cart supersedes any unpaid one.
    final kept = (await _load()).where((o) => !o.isOpen).toList();
    await _save([...kept, order]);
    return Right(order);
  }

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) async {
    if (_network.failure case final failure?) return Left(failure);
    final order = (await _load()).where((o) => o.id == orderId).firstOrNull;
    if (order == null) return const Left(ServerFailure('We could not find that order.'));
    return Right(order);
  }

  @override
  Future<Either<Failure, Order?>> getOpenOrder() async {
    final open = (await _load()).where((o) => o.isOpen).toList();
    return Right(open.isEmpty ? null : open.last);
  }

  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) async {
    if (_network.failure case final failure?) return Left(failure);
    final orders = await _load();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return const Left(ServerFailure('We could not find that order.'));
    if (orders[index].status == OrderStatus.pendingVerification) {
      orders[index] = orders[index].copyWith(status: OrderStatus.awaitingPayment);
      await _save(orders);
    }
    return Right(orders[index]);
  }

  @override
  Future<Either<Failure, Order>> pay({required String orderId, required PaymentMethod method}) async {
    await Future.delayed(_latency);
    if (_network.failure case final failure?) return Left(failure);
    final orders = await _load();
    final index = orders.indexWhere((o) => o.id == orderId);
    if (index == -1) return const Left(ServerFailure('We could not find that order.'));
    final order = orders[index];
    if (order.status == OrderStatus.paid) return Right(order); // idempotent
    if (order.status == OrderStatus.pendingVerification) {
      return const Left(ValidationFailure('Verify your identity before paying.'));
    }
    if (failNextPayment) {
      failNextPayment = false;
      return const Left(ServerFailure('The payment was not completed. You have not been charged.'));
    }
    orders[index] = order.copyWith(status: OrderStatus.paid);
    await _save(orders);
    return Right(orders[index]);
  }

  @override
  Future<void> clearLocalOrders() async {
    await _store.delete(_ordersKey);
    await _store.delete(_counterKey);
  }
}
