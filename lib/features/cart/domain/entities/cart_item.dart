import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

class CartItem extends Equatable {
  const CartItem({required this.plan, required this.quantity});

  final Plan plan;
  final int quantity;

  int get lineTotalCents => plan.priceCents * quantity;

  CartItem copyWith({int? quantity}) => CartItem(plan: plan, quantity: quantity ?? this.quantity);

  @override
  List<Object?> get props => [plan, quantity];
}
