import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/kyc_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';

enum HomeLoad { loading, loaded, failure }

/// One independently loaded source on the Home dashboard.
class HomeSection<T> extends Equatable {
  const HomeSection({this.load = HomeLoad.loading, this.data, this.failure});

  final HomeLoad load;
  final T? data;
  final Failure? failure;

  @override
  List<Object?> get props => [load, data, failure];
}

class HomeOverviewState extends Equatable {
  const HomeOverviewState({
    this.services = const HomeSection(),
    this.openInvoices = const HomeSection(),
    this.kyc = const HomeSection(),
  });

  /// Non-cancelled services, API order (newest first).
  final HomeSection<List<SubscriberService>> services;

  /// Open invoices, API order.
  final HomeSection<List<SubscriberInvoice>> openInvoices;

  /// Null data: no check yet. A `subscriber_not_found` failure means no account.
  final HomeSection<KycRecord?> kyc;

  /// The customer has a subscriber account: at least one non-cancelled
  /// service. (Passes are separate and always shown.)
  bool get hasServices => (services.data ?? const []).isNotEmpty;

  @override
  List<Object?> get props => [services, openInvoices, kyc];
}

/// The subscriber part of the Home dashboard: services, open invoices and ID
/// check status. Each source loads on its own, so one failing never blanks
/// the others. Passes come from the existing `PassesCubit`.
class HomeOverviewCubit extends Cubit<HomeOverviewState> {
  HomeOverviewCubit(this._subscribers, this._invoices, this._kyc)
    : super(const HomeOverviewState());

  final SubscriberRepository _subscribers;
  final InvoiceRepository _invoices;
  final KycRepository _kyc;
  bool _started = false;

  /// Loads once; later calls (screen rebuilds) do nothing. Use [load] to refresh.
  Future<void> ensureLoaded() => _started ? Future.value() : load();

  /// Reloads every source. Data already on screen stays until the new answer
  /// arrives, and a failed refresh keeps it.
  Future<void> load() async {
    _started = true;
    await Future.wait([loadServices(), loadInvoices(), loadKyc()]);
  }

  Future<void> loadServices() async {
    if (state.services.load == HomeLoad.failure) {
      emit(_with(services: const HomeSection()));
    }
    final result = await _subscribers.listServices();
    if (isClosed) return;
    result.match(
      (f) => emit(_with(services: _failed(state.services, f))),
      (all) => emit(
        _with(
          services: HomeSection(
            load: HomeLoad.loaded,
            data: [
              for (final s in all)
                if (s.status != ServiceStatus.cancelled) s,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> loadInvoices() async {
    if (state.openInvoices.load == HomeLoad.failure) {
      emit(_with(openInvoices: const HomeSection()));
    }
    final result = await _invoices.list(openOnly: true);
    if (isClosed) return;
    result.match(
      (f) => emit(_with(openInvoices: _failed(state.openInvoices, f))),
      (all) => emit(
        _with(
          openInvoices: HomeSection(
            load: HomeLoad.loaded,
            // Defensive: the server filters, but never show a paid invoice as due.
            data: [
              for (final i in all)
                if (i.isOpen) i,
            ],
          ),
        ),
      ),
    );
  }

  Future<void> loadKyc() async {
    if (state.kyc.load == HomeLoad.failure) {
      emit(_with(kyc: const HomeSection()));
    }
    final result = await _kyc.getStatus();
    if (isClosed) return;
    result.match(
      (f) => emit(_with(kyc: _failed(state.kyc, f))),
      (record) => emit(
        _with(
          kyc: HomeSection(load: HomeLoad.loaded, data: record),
        ),
      ),
    );
  }

  /// A failed refresh keeps the last good data on screen.
  HomeSection<T> _failed<T>(HomeSection<T> before, Failure f) =>
      before.load == HomeLoad.loaded
      ? before
      : HomeSection(load: HomeLoad.failure, failure: f);

  HomeOverviewState _with({
    HomeSection<List<SubscriberService>>? services,
    HomeSection<List<SubscriberInvoice>>? openInvoices,
    HomeSection<KycRecord?>? kyc,
  }) => HomeOverviewState(
    services: services ?? state.services,
    openInvoices: openInvoices ?? state.openInvoices,
    kyc: kyc ?? state.kyc,
  );
}
