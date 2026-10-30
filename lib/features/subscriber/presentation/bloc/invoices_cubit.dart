import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';

enum InvoicesStatus { loading, loaded, failed }

class InvoicesState extends Equatable {
  const InvoicesState({this.status = InvoicesStatus.loading, this.invoices = const [], this.failure});

  final InvoicesStatus status;

  /// In the API's order (newest first).
  final List<SubscriberInvoice> invoices;
  final Failure? failure;

  /// Unpaid invoices, in the API's order.
  List<SubscriberInvoice> get open => [
    for (final i in invoices)
      if (i.isOpen) i,
  ];

  /// Everything else (paid, cancelled, written off), in the API's order.
  List<SubscriberInvoice> get earlier => [
    for (final i in invoices)
      if (!i.isOpen) i,
  ];

  @override
  List<Object?> get props => [status, invoices, failure];
}

/// The invoices list. A refresh keeps what is on screen while it reloads, and
/// keeps it when the reload fails (the failure rides along as a message).
class InvoicesCubit extends Cubit<InvoicesState> {
  InvoicesCubit(this._repository) : super(const InvoicesState()) {
    load();
  }

  final InvoiceRepository _repository;

  Future<void> load() async {
    emit(const InvoicesState());
    await _fetch();
  }

  /// Pull to refresh.
  Future<void> refresh() async {
    final before = state;
    if (before.status != InvoicesStatus.loaded) return load();
    await _fetch(keep: before);
  }

  Future<void> _fetch({InvoicesState? keep}) async {
    final result = await _repository.list();
    if (isClosed) return;
    result.match(
      (failure) => emit(
        keep != null
            ? InvoicesState(status: InvoicesStatus.loaded, invoices: keep.invoices, failure: failure)
            : InvoicesState(status: InvoicesStatus.failed, failure: failure),
      ),
      (invoices) => emit(InvoicesState(status: InvoicesStatus.loaded, invoices: invoices)),
    );
  }
}
