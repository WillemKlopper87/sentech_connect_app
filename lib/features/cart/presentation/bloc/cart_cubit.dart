import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

class CartState extends Equatable {
  const CartState({this.items = const []});

  final List<CartItem> items;

  int get itemCount => items.fold(0, (sum, i) => sum + i.quantity);

  int get totalCents => items.fold(0, (sum, i) => sum + i.lineTotalCents);

  @override
  List<Object?> get props => [items];
}

/// Provided once at the app root (see app/app.dart) so the cart survives
/// navigation between the Shop tab, the cart review screen, and checkout.
///
/// Only one Home 5G plan may be held at a time (a customer can't have two
/// home connections in one order) — MiFi and Vouchers can have any quantity.
class CartCubit extends Cubit<CartState> {
  CartCubit() : super(const CartState());

  void addItem(Plan plan) {
    final items = [...state.items];
    final existingIndex = items.indexWhere((i) => i.plan.id == plan.id);

    if (existingIndex != -1) {
      items[existingIndex] = items[existingIndex].copyWith(quantity: items[existingIndex].quantity + 1);
    } else if (plan.category == ProductCategory.home5g) {
      items.removeWhere((i) => i.plan.category == ProductCategory.home5g);
      items.add(CartItem(plan: plan, quantity: 1));
    } else {
      items.add(CartItem(plan: plan, quantity: 1));
    }
    emit(CartState(items: items));
  }

  void setQuantity(String planId, int quantity) {
    if (quantity <= 0) {
      removeItem(planId);
      return;
    }
    final items = state.items
        .map((i) => i.plan.id == planId ? i.copyWith(quantity: quantity) : i)
        .toList();
    emit(CartState(items: items));
  }

  void removeItem(String planId) {
    emit(CartState(items: state.items.where((i) => i.plan.id != planId).toList()));
  }

  void clear() => emit(const CartState());
}
