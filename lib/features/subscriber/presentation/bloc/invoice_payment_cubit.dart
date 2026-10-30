import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart' show PaymentCubit, defaultPollDelays;
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum InvoicePaymentStatus {
  /// Nothing started.
  idle,

  /// Asking the server for the hosted payment page.
  starting,

  /// The page must open [InvoicePaymentState.handoff], then call `handoffFinished`.
  handoff,

  /// Polling the invoice until the gateway's notification has been processed.
  confirming,

  /// No confirmation within the polling window; "Check again" is offered.
  stillPending,

  /// The payment could not be started (or was refused); retrying is safe.
  payFailed,

  /// The server says the invoice is paid.
  paid,

  /// The invoice cannot be paid (void, written off, paid elsewhere) or the
  /// provider collects its own money; see [InvoicePaymentState.failure].
  closed,
}

class InvoicePaymentState extends Equatable {
  const InvoicePaymentState({
    this.status = InvoicePaymentStatus.idle,
    this.handoff,
    this.invoice,
    this.service,
    this.failure,
  });

  final InvoicePaymentStatus status;
  final PaymentHandoff? handoff;

  /// The invoice as the server last reported it (set once paid or closed).
  final SubscriberInvoice? invoice;

  /// The invoice's service, re-read after payment so the screen can say what
  /// happens next. Null when it could not be read: the outcome line then
  /// stays neutral rather than guessing.
  final SubscriberService? service;
  final Failure? failure;

  InvoicePaymentState copyWith({
    InvoicePaymentStatus? status,
    PaymentHandoff? handoff,
    SubscriberInvoice? invoice,
    SubscriberService? service,
    Failure? failure,
  }) => InvoicePaymentState(
    status: status ?? this.status,
    handoff: handoff ?? this.handoff,
    invoice: invoice ?? this.invoice,
    service: service ?? this.service,
    failure: failure,
  );

  @override
  List<Object?> get props => [status, handoff, invoice, service, failure];
}

/// Pays one invoice: start the hosted payment, hand off to the gateway, then
/// poll the invoice (bounded, same schedule as an order) until the server says
/// `paid`. The result is decided ONLY by the server's invoice status: a return
/// URL or a closed web view just starts the polling. Mirrors [PaymentCubit].
class InvoicePaymentCubit extends Cubit<InvoicePaymentState> {
  InvoicePaymentCubit(
    this._invoices,
    this._subscriber,
    this.invoiceId, {
    this._pollDelays = defaultPollDelays,
    Future<void> Function(Duration)? wait,
    String Function()? newKey,
  }) : _wait = wait ?? ((d) => Future<void>.delayed(d)),
       _newKey = newKey ?? newIdempotencyKey,
       super(const InvoicePaymentState());

  static const handoffInvalidCode = PaymentCubit.handoffInvalidCode;

  final InvoiceRepository _invoices;
  final SubscriberRepository _subscriber;
  final String invoiceId;
  final List<Duration> _pollDelays;
  final Future<void> Function(Duration) _wait;
  final String Function() _newKey;

  /// One key per payment attempt: a retry after a lost response (offline)
  /// reuses it; a started or definitively refused attempt gets a new one.
  String? _attemptKey;

  Future<void> pay() async {
    const blocked = {
      InvoicePaymentStatus.starting,
      InvoicePaymentStatus.handoff,
      InvoicePaymentStatus.confirming,
      InvoicePaymentStatus.paid,
      InvoicePaymentStatus.closed,
    };
    if (blocked.contains(state.status)) return;
    emit(state.copyWith(status: InvoicePaymentStatus.starting));
    final key = _attemptKey ??= _newKey();
    final result = await _invoices.startCheckout(invoiceId, idempotencyKey: key);
    if (isClosed) return;
    switch (result) {
      case Left(value: final failure):
        if (failure is! NetworkFailure) _attemptKey = null;
        if (failure is CollectionExternalFailure) {
          emit(state.copyWith(status: InvoicePaymentStatus.closed, failure: failure));
        } else if (failure is InvoiceNotPayableFailure) {
          await _routeByServerStatus(failure);
        } else {
          emit(state.copyWith(status: InvoicePaymentStatus.payFailed, failure: failure));
        }
      case Right(value: final handoff):
        _attemptKey = null;
        if (!handoff.isDemo && !isAllowedPaymentUrl(handoff.url, allowLocalHttp: kDebugMode)) {
          emit(
            state.copyWith(
              status: InvoicePaymentStatus.payFailed,
              failure: const ValidationFailure('We could not open the payment page safely.', handoffInvalidCode),
            ),
          );
          return;
        }
        emit(state.copyWith(status: InvoicePaymentStatus.handoff, handoff: handoff));
    }
  }

  /// The server refused a new payment ("not payable"): the invoice may in fact
  /// have been paid late (or closed), so show what is true.
  Future<void> _routeByServerStatus(Failure refusal) async {
    final result = await _invoices.get(invoiceId);
    if (isClosed) return;
    final invoice = result.match((_) => null, (i) => i);
    if (invoice?.status == InvoiceStatus.paid) return _paid(invoice!);
    emit(state.copyWith(status: InvoicePaymentStatus.closed, invoice: invoice, failure: refusal));
  }

  /// Called by the page once the gateway page is closed / returned.
  Future<void> handoffFinished() async {
    if (isClosed || state.status != InvoicePaymentStatus.handoff) return;
    await _confirm();
  }

  Future<void> checkAgain() async {
    if (isClosed || state.status != InvoicePaymentStatus.stillPending) return;
    await _confirm();
  }

  Future<void> _confirm() async {
    emit(state.copyWith(status: InvoicePaymentStatus.confirming));
    for (final delay in _pollDelays) {
      await _wait(delay);
      if (isClosed) return;
      final result = await _invoices.get(invoiceId);
      if (isClosed) return;
      // An offline blip is not an answer: keep waiting, bounded by the schedule.
      final invoice = result.match((_) => null, (i) => i);
      if (invoice == null) continue;
      switch (invoice.status) {
        case InvoiceStatus.paid:
          return _paid(invoice);
        case InvoiceStatus.voided || InvoiceStatus.writtenOff:
          emit(
            state.copyWith(
              status: InvoicePaymentStatus.closed,
              invoice: invoice,
              failure: const InvoiceNotPayableFailure(),
            ),
          );
          return;
        case InvoiceStatus.open:
          break;
      }
    }
    if (isClosed) return;
    emit(state.copyWith(status: InvoicePaymentStatus.stillPending));
  }

  Future<void> _paid(SubscriberInvoice invoice) async {
    // Re-read the service: payment does not always start it (ID check,
    // installation), and the platform says which gate is left.
    final service = (await _subscriber.getService(invoice.serviceId)).match((_) => null, (s) => s);
    if (isClosed) return;
    emit(state.copyWith(status: InvoicePaymentStatus.paid, invoice: invoice, service: service));
  }
}
