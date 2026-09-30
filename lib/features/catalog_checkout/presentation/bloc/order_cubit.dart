import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

enum OrderLoadStatus { loading, loaded, failure }

class OrderState extends Equatable {
  const OrderState({this.status = OrderLoadStatus.loading, this.order, this.failure});

  final OrderLoadStatus status;
  final Order? order;
  final Failure? failure;

  @override
  List<Object?> get props => [status, order, failure];
}

/// Loads one order by id (confirmation screen).
class OrderCubit extends Cubit<OrderState> {
  OrderCubit(this._repository, this.orderId) : super(const OrderState()) {
    load();
  }

  final CheckoutRepository _repository;
  final String orderId;

  Future<void> load() async {
    emit(const OrderState());
    final result = await _repository.getOrder(orderId);
    if (isClosed) return;
    result.match(
      (failure) => emit(OrderState(status: OrderLoadStatus.failure, failure: failure)),
      (order) => emit(OrderState(status: OrderLoadStatus.loaded, order: order)),
    );
  }
}

/// Drives the dashboard "finish your order" banner: the customer's unpaid
/// order, if any.
class OpenOrderCubit extends Cubit<Order?> {
  OpenOrderCubit(this._repository) : super(null) {
    refresh();
  }

  final CheckoutRepository _repository;

  Future<void> refresh() async {
    final result = await _repository.getOpenOrder();
    if (isClosed) return;
    emit(result.getOrElse((_) => null));
  }
}
