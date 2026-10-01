import 'package:equatable/equatable.dart';

/// Where an order is in the create -> verify identity -> pay lifecycle.
///
/// Identity (RICA) is verified BEFORE the customer is charged, so a failed
/// or abandoned verification never leaves someone paid-but-unserved. The
/// order is persisted at every step so the customer can resume after
/// killing the app, losing signal or failing a liveness check.
enum OrderStatus {
  /// Created from the cart; RICA verification still required.
  pendingVerification,

  /// Identity verified; waiting for payment.
  awaitingPayment,

  /// Paid — service fulfilment can start.
  paid,

  paymentFailed,
  expired,
  cancelled,
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.planName,
    required this.totalCents,
    this.status = OrderStatus.pendingVerification,
    this.isHotspotPass = false,
  });

  /// Opaque identifier used in routes (`/rica/:orderId`). Never the
  /// customer-facing [orderNumber].
  final String id;
  final String orderNumber;
  final String planName;

  /// Total in integer cents (ZAR); the server owns it.
  final int totalCents;
  final OrderStatus status;

  /// Hotspot passes have no identity or router installation flow.
  final bool isHotspotPass;

  bool get isOpen =>
      status == OrderStatus.pendingVerification ||
      status == OrderStatus.awaitingPayment ||
      status == OrderStatus.paymentFailed;

  Order copyWith({OrderStatus? status}) => Order(
    id: id,
    orderNumber: orderNumber,
    planName: planName,
    totalCents: totalCents,
    status: status ?? this.status,
    isHotspotPass: isHotspotPass,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'orderNumber': orderNumber,
    'planName': planName,
    'totalCents': totalCents,
    'status': status.name,
    'isHotspotPass': isHotspotPass,
  };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
    id: json['id'] as String,
    orderNumber: json['orderNumber'] as String,
    planName: json['planName'] as String,
    totalCents: _centsFrom(json),
    isHotspotPass: json['isHotspotPass'] == true,
    status: OrderStatus.values.firstWhere(
      (s) => s.name == json['status'],
      orElse: () => OrderStatus.pendingVerification,
    ),
  );

  /// Builds before integer cents stored `totalRands` as a double. A record with
  /// neither field is corrupt: throwing lets the caller discard it rather than
  /// showing a R0.00 order.
  static int _centsFrom(Map<String, dynamic> json) {
    final cents = json['totalCents'];
    if (cents is num) return cents.toInt();
    final rands = json['totalRands'];
    if (rands is num) return (rands * 100).round();
    throw const FormatException('Order has neither totalCents nor totalRands');
  }

  @override
  List<Object?> get props => [
    id,
    orderNumber,
    planName,
    totalCents,
    status,
    isHotspotPass,
  ];
}
