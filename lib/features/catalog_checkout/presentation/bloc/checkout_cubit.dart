import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

enum CheckoutStatus { selecting, paying, paid, failure }

class CheckoutState extends Equatable {
  const CheckoutState({
    required this.items,
    this.method = PaymentMethod.ozow,
    this.status = CheckoutStatus.selecting,
    this.order,
  });

  final List<CartItem> items;
  final PaymentMethod method;
  final CheckoutStatus status;
  final Order? order;

  double get total => items.fold(0.0, (sum, i) => sum + i.lineTotal);

  CheckoutState copyWith({PaymentMethod? method, CheckoutStatus? status, Order? order}) {
    return CheckoutState(
      items: items,
      method: method ?? this.method,
      status: status ?? this.status,
      order: order ?? this.order,
    );
  }

  @override
  List<Object?> get props => [items, method, status, order];
}

class CheckoutCubit extends Cubit<CheckoutState> {
  CheckoutCubit(this._repository, this._cartCubit)
      : super(CheckoutState(items: _cartCubit.state.items));

  final CheckoutRepository _repository;
  final CartCubit _cartCubit;

  void selectMethod(PaymentMethod method) => emit(state.copyWith(method: method));

  Future<void> pay() async {
    emit(state.copyWith(status: CheckoutStatus.paying));
    final result = await _repository.pay(items: state.items, method: state.method);
    result.match(
      (_) => emit(state.copyWith(status: CheckoutStatus.failure)),
      (order) {
        _cartCubit.clear();
        emit(state.copyWith(status: CheckoutStatus.paid, order: order));
      },
    );
  }
}
