import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_tickets_repository.dart';

class IncidentsState extends Equatable {
  const IncidentsState({this.loaded = false, this.open = const [], this.failed = false});

  final bool loaded;

  /// Incidents that are not resolved, as the server listed them (newest first).
  final List<Incident> open;

  /// The last load failed. Never shown as an error: an incident notice is extra
  /// information and its absence must not block or alarm the page it sits on.
  final bool failed;

  @override
  List<Object?> get props => [loaded, open, failed];
}

/// The known network incidents of the customer's provider (public route).
/// A failed load is silent by design.
class IncidentsCubit extends Cubit<IncidentsState> {
  IncidentsCubit(this._repository, {this.siteId}) : super(const IncidentsState()) {
    load();
  }

  final SupportTicketsRepository _repository;
  final String? siteId;
  int _generation = 0;

  Future<void> load() async {
    final generation = ++_generation;
    final result = await _repository.incidents(siteId: siteId);
    if (isClosed || generation != _generation) return;
    result.match(
      (_) => emit(const IncidentsState(loaded: true, failed: true)),
      (incidents) => emit(IncidentsState(loaded: true, open: [for (final i in incidents) if (i.isOpen) i])),
    );
  }
}
