import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

enum CheckoutStatus { reviewing, creating, created, failure }

/// Step 1 of checkout: review the cart and create the (unpaid) order.
/// Payment happens later, after RICA, in [PaymentCubit].
class CheckoutState extends Equatable {
  const CheckoutState({
    required this.items,
    this.status = CheckoutStatus.reviewing,
    this.order,
    this.failure,
  });

  final List<CartItem> items;
  final CheckoutStatus status;
  final Order? order;
  final Failure? failure;

  double get total => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  CheckoutState copyWith({CheckoutStatus? status, Order? order, Failure? failure}) {
    return CheckoutState(
      items: items,
      status: status ?? this.status,
      order: order ?? this.order,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [items, status, order, failure];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._repository, CartCubit cartCubit)
      : super(CheckoutState(items: cartCubit.state.items));

  final CheckoutRepository _repository;

  Future<void> createOrder() async {
    if (state.status == CheckoutStatus.creating) return; // double-tap guard
    emit(state.copyWith(status: CheckoutStatus.creating));
    final result = await _repository.createOrder(items: state.items);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: CheckoutStatus.failure, failure: failure)),
      (order) => emit(state.copyWith(status: CheckoutStatus.created, order: order)),
    );
  }
}
