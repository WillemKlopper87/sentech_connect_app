import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/presentation/bloc/cart_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/repositories/checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';

enum PaymentStatus {
  loading,

  /// Order not found / could not be loaded; see [PaymentState.failure].
  loadFailed,

  /// Identity has not been verified yet; the page sends the customer to RICA.
  needsVerification,
  ready,

  /// Asking the server for the hosted payment page.
  starting,

  /// The page must open [PaymentState.handoff], then call `handoffFinished`.
  handoff,

  /// Polling the order until the gateway's notification has been processed.
  confirming,

  /// No confirmation within the polling window; "Check again" is offered.
  stillPending,

  /// Declined / failed; the order is still payable, retrying is safe.
  payFailed,
  paid,

  /// Expired or cancelled: cannot be paid any more.
  closed,
}

/// About 52 s in total; the first check is immediate.
const defaultPollDelays = <Duration>[
  Duration.zero,
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 5),
  Duration(seconds: 8),
  Duration(seconds: 8),
  Duration(seconds: 10),
  Duration(seconds: 10),
];

class PaymentState extends Equatable {
  const PaymentState({
    this.status = PaymentStatus.loading,
    this.order,
    this.handoff,
    this.failure,
  });

  final PaymentStatus status;
  final Order? order;
  final PaymentHandoff? handoff;
  final Failure? failure;

  PaymentState copyWith({
    PaymentStatus? status,
    Order? order,
    PaymentHandoff? handoff,
    Failure? failure,
  }) => PaymentState(
    status: status ?? this.status,
    order: order ?? this.order,
    handoff: handoff ?? this.handoff,
    failure: failure,
  );

  @override
  List<Object?> get props => [status, order, handoff, failure];
}

/// Pay for an order: start the hosted payment, hand off to the gateway,
/// then poll the order (bounded) until the server says paid / failed. The
/// order comes from the repository by id, so this survives process death.
///
/// The result is decided ONLY by the server's order status: a return URL (or
/// a closed web view) just starts the polling.
class PaymentCubit extends Cubit<PaymentState> {
  PaymentCubit(
    this._repository,
    this._cartCubit,
    this.orderId, {
    this._pollDelays = defaultPollDelays,
    Future<void> Function(Duration)? wait,
  }) : _wait = wait ?? ((d) => Future<void>.delayed(d)),
       super(const PaymentState()) {
    load();
  }

  static const _declined = ValidationFailure(
    'The payment was not completed. You have not been charged.',
    'payment_failed',
  );

  /// The hand-off URL failed our own safety rules; nothing was opened.
  static const handoffInvalidCode = 'handoff_invalid';

  final CheckoutRepository _repository;
  final CartCubit _cartCubit;
  final String orderId;
  final List<Duration> _pollDelays;
  final Future<void> Function(Duration) _wait;

  Future<void> load() async {
    emit(state.copyWith(status: PaymentStatus.loading));
    final result = await _repository.getOrder(orderId);
    if (isClosed) return;
    result.match(
      (failure) => emit(
        state.copyWith(status: PaymentStatus.loadFailed, failure: failure),
      ),
      (order) => emit(
        state.copyWith(
          status: _statusFor(order),
          order: order,
          failure: order.status == OrderStatus.paymentFailed ? _declined : null,
        ),
      ),
    );
  }

  PaymentStatus _statusFor(Order order) => switch (order.status) {
    OrderStatus.pendingVerification => PaymentStatus.needsVerification,
    OrderStatus.awaitingPayment => PaymentStatus.ready,
    OrderStatus.paymentFailed => PaymentStatus.payFailed,
    OrderStatus.paid => PaymentStatus.paid,
    OrderStatus.expired || OrderStatus.cancelled => PaymentStatus.closed,
  };

  Future<void> pay() async {
    const blocked = {
      PaymentStatus.loading,
      PaymentStatus.loadFailed,
      PaymentStatus.needsVerification,
      PaymentStatus.starting,
      PaymentStatus.handoff,
      PaymentStatus.confirming,
      PaymentStatus.paid,
      PaymentStatus.closed,
    };
    if (blocked.contains(state.status)) return;
    emit(state.copyWith(status: PaymentStatus.starting));
    final result = await _repository.startPayment(orderId: orderId);
    if (isClosed) return;
    switch (result) {
      case Left(value: final failure):
        if (failure is ValidationFailure &&
            failure.code == 'order_not_payable') {
          await _routeByServerStatus(failure);
        } else {
          emit(
            state.copyWith(status: PaymentStatus.payFailed, failure: failure),
          );
        }
      case Right(value: final handoff):
        if (!handoff.isDemo &&
            !isAllowedPaymentUrl(handoff.url, allowLocalHttp: kDebugMode)) {
          emit(
            state.copyWith(
              status: PaymentStatus.payFailed,
              failure: const ValidationFailure(
                'We could not open the payment page safely.',
                handoffInvalidCode,
              ),
            ),
          );
          return;
        }
        emit(state.copyWith(status: PaymentStatus.handoff, handoff: handoff));
    }
  }

  /// The server refused a new payment ("not payable"): the order may in fact
  /// have been paid late (or expired/cancelled), so show what is true.
  Future<void> _routeByServerStatus(Failure refusal) async {
    final result = await _repository.getOrder(orderId);
    if (isClosed) return;
    final order = result.match((_) => null, (o) => o);
    switch (order?.status) {
      case OrderStatus.paid:
        _cartCubit.clearForPaidOrder(order!.id);
        emit(state.copyWith(status: PaymentStatus.paid, order: order));
      case OrderStatus.expired || OrderStatus.cancelled:
        emit(
          state.copyWith(
            status: PaymentStatus.closed,
            order: order,
            failure: refusal,
          ),
        );
      case _:
        emit(state.copyWith(status: PaymentStatus.payFailed, failure: refusal));
    }
  }

  /// Called by the page once the gateway page is closed / returned.
  Future<void> handoffFinished() async {
    if (isClosed || state.status != PaymentStatus.handoff) return;
    await _confirm();
  }

  Future<void> checkAgain() async {
    if (isClosed || state.status != PaymentStatus.stillPending) return;
    await _confirm();
  }

  Future<void> _confirm() async {
    emit(state.copyWith(status: PaymentStatus.confirming));
    Order? closedOrder;
    for (final delay in _pollDelays) {
      await _wait(delay);
      if (isClosed) return;
      final result = await _repository.getOrder(orderId);
      if (isClosed) return;
      final order = switch (result) {
        Right(value: final o) => o,
        Left() => null, // offline blip: keep waiting, bounded by the schedule
      };
      if (order == null) continue;
      closedOrder = null;
      switch (order.status) {
        case OrderStatus.paid:
          _cartCubit.clearForPaidOrder(order.id);
          emit(state.copyWith(status: PaymentStatus.paid, order: order));
          return;
        case OrderStatus.paymentFailed:
          emit(
            state.copyWith(
              status: PaymentStatus.payFailed,
              order: order,
              failure: _declined,
            ),
          );
          return;
        case OrderStatus.expired || OrderStatus.cancelled:
          // A late payment can still fulfil an expired order (server rule),
          // so keep polling the window out before calling it closed.
          closedOrder = order;
        case OrderStatus.pendingVerification || OrderStatus.awaitingPayment:
          break;
      }
    }
    if (isClosed) return;
    if (closedOrder != null) {
      emit(state.copyWith(status: PaymentStatus.closed, order: closedOrder));
      return;
    }
    emit(state.copyWith(status: PaymentStatus.stillPending));
  }
}
