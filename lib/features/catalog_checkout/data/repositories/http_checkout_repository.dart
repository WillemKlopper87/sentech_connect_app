import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/api_client.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

/// Orders on the platform (`/v1/orders`). The server owns prices, totals,
/// order state and resumability, so nothing is stored on the device.
class HttpCheckoutRepository implements CheckoutRepository {
  HttpCheckoutRepository(this._api, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey;

  final ApiClient _api;
  final String Function() _newKey;

  @override
  Future<Either<Failure, Order>> createOrder({
    required List<CartItem> items,
    String? idempotencyKey,
  }) async {
    if (items.isEmpty) {
      return const Left(ValidationFailure('Your cart is empty.'));
    }
    final scope = await _api.captureScope();
    return _api.post<Order>(
      '/v1/orders',
      scope: scope,
      body: {
        'lines': [
          for (final item in items)
            {'product_id': item.plan.id, 'quantity': item.quantity},
        ],
      },
      idempotencyKey: idempotencyKey ?? _newKey(),
      decode: (data) => orderFromJson(Map<String, Object?>.from(data! as Map)),
    );
  }

  @override
  Future<Either<Failure, Order>> getOrder(String orderId) async {
    final scope = await _api.captureScope();
    return _api.get<Order>(
      '/v1/orders/${Uri.encodeComponent(orderId)}',
      scope: scope,
      timeout: const Duration(seconds: 10),
      decode: (data) => orderFromJson(Map<String, Object?>.from(data! as Map)),
    );
  }

  @override
  Future<Either<Failure, Order?>> getOpenOrder() async {
    final scope = await _api.captureScope();
    String? cursor;
    final seen = <String>{};
    // The server sorts newest first by (created_at, id). Continue beyond
    // completed orders; a customer may have more than one page of history.
    for (var page = 0; page < 100; page++) {
      final result = await _api.get<(Order?, String?)>(
        '/v1/orders',
        scope: scope,
        query: {'limit': 100, 'cursor': ?cursor},
        decode: (data) {
          final map = data! as Map;
          Order? open;
          for (final item in map['items']! as List) {
            final json = Map<String, Object?>.from(item as Map);
            final status = orderStatusFromApi(json['status']! as String);
            if (open == null &&
                (status == OrderStatus.awaitingPayment ||
                    status == OrderStatus.paymentFailed)) {
              open = orderFromJson(json);
            }
          }
          return (open, map['next_cursor'] as String?);
        },
      );
      switch (result) {
        case Left(value: final failure):
          return Left(failure);
        case Right(value: (final order, final next)):
          if (order != null || next == null) return Right(order);
          if (!seen.add(next)) {
            return const Left(
              ServerFailure(
                'We could not load your open order. Please try again.',
              ),
            );
          }
          cursor = next;
      }
    }
    return const Left(
      ServerFailure('We could not load your open order. Please try again.'),
    );
  }

  /// Hotspot passes skip RICA (spec §3); identity checks are flagged off.
  @override
  Future<Either<Failure, Order>> markIdentityVerified(String orderId) async =>
      const Left(
        ValidationFailure(
          'Identity checks are not needed for this order.',
          'rica_disabled',
        ),
      );

  @override
  Future<Either<Failure, PaymentHandoff>> startPayment({
    required String orderId,
  }) => _api.post<PaymentHandoff>(
    '/v1/orders/${Uri.encodeComponent(orderId)}/checkout',
    timeout: const Duration(seconds: 30),
    decode: (data) {
      final handoff = paymentHandoffFromJson(
        Map<String, Object?>.from(data! as Map),
      );
      // 'demo' is the mock repository's marker and skips URL validation in
      // the payment cubit; a real server must never be able to use it.
      if (handoff.isDemo) {
        throw const FormatException('Unexpected demo gateway from the API');
      }
      return handoff;
    },
  );

  @override
  Future<Either<Failure, Order>> cancelOrder(String orderId) => _api.post<Order>(
    '/v1/orders/${Uri.encodeComponent(orderId)}/cancel',
    timeout: const Duration(seconds: 15),
    decode: (data) => orderFromJson(Map<String, Object?>.from(data! as Map)),
  );

  @override
  Future<void> clearLocalOrders() async {}
}

OrderStatus orderStatusFromApi(String status) => switch (status) {
  'draft' || 'awaiting_payment' => OrderStatus.awaitingPayment,
  'failed' => OrderStatus.paymentFailed,
  'paid' || 'fulfilled' => OrderStatus.paid,
  'expired' => OrderStatus.expired,
  'cancelled' => OrderStatus.cancelled,
  _ => throw FormatException('Unknown order status $status'),
};

/// M1 `OrderOut` -> [Order]. The API has no customer-facing number, so the
/// app shows `SC-` + the first 8 characters of the id (ruling R-M4-7).
Order orderFromJson(Map<String, Object?> json) {
  final id = json['id']! as String;
  final total = json['total']! as Map;
  if (total['currency'] != 'ZAR') {
    throw FormatException('Unsupported currency ${total['currency']}');
  }
  final lines = (json['lines']! as List).cast<Map<Object?, Object?>>();
  final String planName;
  if (lines.length == 1) {
    final quantity = lines.single['quantity']! as int;
    final name = lines.single['name']! as String;
    planName = quantity > 1 ? '$name × $quantity' : name;
  } else {
    planName = '${lines.length} items';
  }
  return Order(
    id: id,
    orderNumber: 'SC-${id.replaceAll('-', '').substring(0, 8).toUpperCase()}',
    planName: planName,
    totalCents: total['amount_cents']! as int,
    isHotspotPass: true,
    status: orderStatusFromApi(json['status']! as String),
  );
}

/// M1 `CheckoutOut` -> [PaymentHandoff].
PaymentHandoff paymentHandoffFromJson(Map<String, Object?> json) {
  final amount = json['amount']! as Map;
  if (amount['currency'] != 'ZAR') {
    throw FormatException('Unsupported currency ${amount['currency']}');
  }
  final method = switch (json['method']) {
    'GET' => PaymentHandoffMethod.get,
    'POST' => PaymentHandoffMethod.post,
    final other => throw FormatException('Unknown checkout method $other'),
  };
  return PaymentHandoff(
    paymentId: json['payment_id']! as String,
    reference: json['reference']! as String,
    gateway: json['gateway']! as String,
    method: method,
    url: Uri.parse(json['url']! as String),
    fields: Map<String, String>.from(json['fields']! as Map),
    amountCents: amount['amount_cents']! as int,
  );
}
