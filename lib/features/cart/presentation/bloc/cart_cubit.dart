import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show listEquals;
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

  final Map<String, ({CartState source, List<CartItem> items})>
  _reviewedOrders = {};

  /// Bind an order created from this cart to the exact items the customer
  /// reviewed. A Buy now sheet has its own cart and never binds the root cart.
  void bindCheckoutOrder(
    String orderId,
    List<CartItem> reviewedItems, {
    required CartState source,
  }) {
    // Only the latest review can own the cart. If it changed while the
    // create request was pending, the returned order owns no current items.
    _reviewedOrders.clear();
    if (!identical(state, source) || !listEquals(source.items, reviewedItems)) {
      return;
    }
    _reviewedOrders[orderId] = (
      source: source,
      items: List<CartItem>.unmodifiable(reviewedItems),
    );
  }

  /// A paid order empties only its unchanged source cart. New selections made
  /// while payment was pending belong to a different prospective order.
  void clearForPaidOrder(String orderId) {
    final reviewed = _reviewedOrders.remove(orderId);
    if (reviewed != null &&
        identical(state, reviewed.source) &&
        listEquals(state.items, reviewed.items)) {
      clear();
    }
  }

  void addItem(Plan plan) {
    _reviewedOrders.clear();
    final items = [...state.items];
    final existingIndex = items.indexWhere((i) => i.plan.id == plan.id);

    if (existingIndex != -1) {
      items[existingIndex] = items[existingIndex].copyWith(
        quantity: items[existingIndex].quantity + 1,
      );
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
    _reviewedOrders.clear();
    final items = state.items
        .map((i) => i.plan.id == planId ? i.copyWith(quantity: quantity) : i)
        .toList();
    emit(CartState(items: items));
  }

  void removeItem(String planId) {
    _reviewedOrders.clear();
    emit(
      CartState(items: state.items.where((i) => i.plan.id != planId).toList()),
    );
  }

  void clear() {
    _reviewedOrders.clear();
    emit(const CartState());
  }
}
