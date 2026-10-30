import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';

enum InvoiceDetailStatus { loading, loaded, failed }

class InvoiceDetailState extends Equatable {
  const InvoiceDetailState({this.status = InvoiceDetailStatus.loading, this.invoice, this.failure});

  final InvoiceDetailStatus status;
  final SubscriberInvoice? invoice;
  final Failure? failure;

  @override
  List<Object?> get props => [status, invoice, failure];
}

/// One invoice with its lines, loaded by id from the repository (so the screen
/// survives process death and deep links).
class InvoiceDetailCubit extends Cubit<InvoiceDetailState> {
  InvoiceDetailCubit(this._repository, this.invoiceId) : super(const InvoiceDetailState()) {
    load();
  }

  final InvoiceRepository _repository;
  final String invoiceId;

  Future<void> load() async {
    emit(const InvoiceDetailState());
    await _fetch();
  }

  /// Reloads without blanking the screen (after a payment, pull to refresh).
  /// A failed reload keeps the invoice on screen.
  Future<void> refresh() async {
    if (state.invoice == null) return load();
    await _fetch(keep: state.invoice);
  }

  Future<void> _fetch({SubscriberInvoice? keep}) async {
    final result = await _repository.get(invoiceId);
    if (isClosed) return;
    result.match(
      (failure) => emit(
        keep != null
            ? InvoiceDetailState(status: InvoiceDetailStatus.loaded, invoice: keep)
            : InvoiceDetailState(status: InvoiceDetailStatus.failed, failure: failure),
      ),
      (invoice) => emit(InvoiceDetailState(status: InvoiceDetailStatus.loaded, invoice: invoice)),
    );
  }
}
