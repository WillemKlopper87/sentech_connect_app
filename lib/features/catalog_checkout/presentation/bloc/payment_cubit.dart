import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';

enum PaymentStatus {
  /// Expired or cancelled; cannot start another payment.
  closed,
  loading,

  /// Order not found / could not be loaded — see [PaymentState.failure].
  loadFailed,

  /// Identity has not been verified yet; the page sends the customer to RICA.
  needsVerification,
  ready,
  paying,

  /// Charge failed; the order is still `awaitingPayment` so retrying is safe.
  payFailed,
  paid,
}

class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.loading,
    this.order,
    this.method = PaymentMethod.ozow,
    this.failure,
  });

  final PaymentStatus status;
  final Order? order;
  final PaymentMethod method;
  final Failure? failure;

  PaymentState copyWith({
    PaymentStatus? status,
    Order? order,
    PaymentMethod? method,
    Failure? failure,
  }) {
    return PaymentState(
      status: status ?? this.status,
      order: order ?? this.order,
      method: method ?? this.method,
      failure: failure,
    );
  }

  @override
  List<Object?> get props => [status, order, method, failure];
}

/// Step 3 of checkout: pay for an order whose identity check has passed.
/// The order comes from the repository (by id from the route), never from
/// navigation `extra`, so this works after process death and deep links.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(this._repository, this._cartCubit, this.orderId)
    : super(const PaymentState()) {
    load();
  }

  final CheckoutRepository _repository;
  final CartCubit _cartCubit;
  final String orderId;

  Future<void> load() async {
    emit(state.copyWith(status: PaymentStatus.loading));
    final result = await _repository.getOrder(orderId);
    if (isClosed) return;
    result.match(
      (failure) => emit(
        state.copyWith(status: PaymentStatus.loadFailed, failure: failure),
      ),
      (order) => emit(state.copyWith(status: _statusFor(order), order: order)),
    );
  }

  PaymentStatus _statusFor(Order order) => switch (order.status) {
    OrderStatus.pendingVerification => PaymentStatus.needsVerification,
    OrderStatus.awaitingPayment ||
    OrderStatus.paymentFailed => PaymentStatus.ready,
    OrderStatus.expired || OrderStatus.cancelled => PaymentStatus.closed,
    OrderStatus.paid => PaymentStatus.paid,
  };

  void selectMethod(PaymentMethod method) =>
      emit(state.copyWith(method: method));

  Future<void> pay() async {
    if (state.status == PaymentStatus.paying ||
        state.status == PaymentStatus.closed ||
        state.status == PaymentStatus.loading ||
        state.status == PaymentStatus.loadFailed ||
        state.status == PaymentStatus.paid) {
      return;
    }
    emit(state.copyWith(status: PaymentStatus.paying));
    final result = await _repository.pay(
      orderId: orderId,
      method: state.method,
    );
    if (isClosed) return;
    result.match(
      (failure) => emit(
        state.copyWith(status: PaymentStatus.payFailed, failure: failure),
      ),
      (order) {
        if (order.status == OrderStatus.paid) _cartCubit.clear();
        emit(state.copyWith(status: _statusFor(order), order: order));
      },
    );
  }
}
