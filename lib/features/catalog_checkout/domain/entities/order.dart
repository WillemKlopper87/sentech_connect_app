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
}

class Order extends Equatable {
  const Order({
    required this.id,
    required this.orderNumber,
    required this.planName,
    required this.totalRands,
    this.status = OrderStatus.pendingVerification,
  });

  /// Opaque identifier used in routes (`/rica/:orderId`). Never the
  /// customer-facing [orderNumber].
  final String id;
  final String orderNumber;
  final String planName;
  final double totalRands;
  final OrderStatus status;

  bool get isOpen => status != OrderStatus.paid;

  Order copyWith({OrderStatus? status}) => Order(
        id: id,
        orderNumber: orderNumber,
        planName: planName,
        totalRands: totalRands,
        status: status ?? this.status,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'orderNumber': orderNumber,
        'planName': planName,
        'totalRands': totalRands,
        'status': status.name,
      };

  factory Order.fromJson(Map<String, dynamic> json) => Order(
        id: json['id'] as String,
        orderNumber: json['orderNumber'] as String,
        planName: json['planName'] as String,
        totalRands: (json['totalRands'] as num).toDouble(),
        status: OrderStatus.values.firstWhere(
          (s) => s.name == json['status'],
          orElse: () => OrderStatus.pendingVerification,
        ),
      );

  @override
  List<Object?> get props => [id, orderNumber, planName, totalRands, status];
}
