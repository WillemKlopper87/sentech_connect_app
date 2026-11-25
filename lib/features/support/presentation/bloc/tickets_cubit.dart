import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_tickets_repository.dart';

enum TicketsStatus { loading, ready, unavailable, error }

class TicketsState extends Equatable {
  const TicketsState({
    this.status = TicketsStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.failure,
    this.moreFailure,
  });

  final TicketsStatus status;
  final List<Ticket> items;
  final String? nextCursor;
  final bool loadingMore;
  final Failure? failure;

  /// The next page failed: the pages already loaded stay, with a retry.
  final Failure? moreFailure;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [status, items, nextCursor, loadingMore, failure, moreFailure];
}

/// The customer's tickets, newest first, one keyset page at a time. A refresh
/// replaces the list (and drops a next-page request still in flight); a next
/// page never appends a reference that is already shown.
class TicketsCubit extends Cubit<TicketsState> {
  TicketsCubit(this._repository) : super(const TicketsState()) {
    load();
  }

  final SupportTicketsRepository _repository;
  int _generation = 0;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    final visible = keepVisible && state.status == TicketsStatus.ready;
    if (!visible) emit(const TicketsState());
    final result = await _repository.list();
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) {
        if (failure is TicketsNotAvailableFailure) {
          emit(TicketsState(status: TicketsStatus.unavailable, failure: failure));
        } else if (!visible) {
          emit(TicketsState(status: TicketsStatus.error, failure: failure));
        } else if (state.loadingMore) {
          // The refresh failed and replaced the page in flight: its spinner must not stay on.
          emit(TicketsState(status: TicketsStatus.ready, items: state.items, nextCursor: state.nextCursor));
        }
      },
      (page) => emit(TicketsState(status: TicketsStatus.ready, items: page.items, nextCursor: page.nextCursor)),
    );
  }

  Future<void> refresh() => load(keepVisible: true);

  /// Loads the next page. Ignored while a page is loading and once the list has ended.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (isClosed || cursor == null || state.loadingMore || state.status != TicketsStatus.ready) return;
    final generation = _generation;
    emit(TicketsState(status: TicketsStatus.ready, items: state.items, nextCursor: cursor, loadingMore: true));
    final result = await _repository.list(cursor: cursor);
    if (isClosed) return;
    if (generation != _generation) {
      if (state.loadingMore) {
        emit(TicketsState(status: TicketsStatus.ready, items: state.items, nextCursor: state.nextCursor));
      }
      return;
    }
    result.match(
      (failure) => emit(TicketsState(status: TicketsStatus.ready, items: state.items, nextCursor: cursor, moreFailure: failure)),
      (page) {
        final shown = {for (final t in state.items) t.reference};
        emit(
          TicketsState(
            status: TicketsStatus.ready,
            items: [...state.items, for (final t in page.items) if (!shown.contains(t.reference)) t],
            nextCursor: page.nextCursor,
          ),
        );
      },
    );
  }
}
