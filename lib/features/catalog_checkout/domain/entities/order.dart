import 'package:equatable/equatable.dart';

class Order extends Equatable {
  const Order({required this.orderNumber, required this.planName, required this.totalRands});

  final String orderNumber;
  final String planName;
  final double totalRands;

  @override
  List<Object?> get props => [orderNumber, planName, totalRands];
}
