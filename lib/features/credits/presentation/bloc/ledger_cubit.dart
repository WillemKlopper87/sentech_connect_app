import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';

enum LedgerStatus { loading, ready, unavailable, error }

class LedgerState extends Equatable {
  const LedgerState({
    this.status = LedgerStatus.loading,
    this.items = const [],
    this.nextCursor,
    this.loadingMore = false,
    this.failure,
    this.moreFailure,
  });

  final LedgerStatus status;
  final List<CreditEntry> items;
  final String? nextCursor;
  final bool loadingMore;
  final Failure? failure;

  /// The next page failed: the pages already loaded stay, with a retry.
  final Failure? moreFailure;

  bool get hasMore => nextCursor != null;

  @override
  List<Object?> get props => [status, items, nextCursor, loadingMore, failure, moreFailure];
}

/// The credits history, newest first, one keyset page at a time.
class LedgerCubit extends Cubit<LedgerState> {
  LedgerCubit(this._repository) : super(const LedgerState()) {
    load();
  }

  final CreditsRepository _repository;
  int _generation = 0;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    if (!keepVisible || state.status != LedgerStatus.ready) emit(const LedgerState());
    final result = await _repository.ledger();
    if (isClosed || generation != _generation) return;
    result.match((failure) {
      if (failure is CreditsNotAvailableFailure) {
        emit(LedgerState(status: LedgerStatus.unavailable, failure: failure));
      } else if (!(keepVisible && state.status == LedgerStatus.ready)) {
        emit(LedgerState(status: LedgerStatus.error, failure: failure));
      }
    }, (page) => emit(LedgerState(status: LedgerStatus.ready, items: page.items, nextCursor: page.nextCursor)));
  }

  Future<void> refresh() => load(keepVisible: true);

  /// Loads the next page. Ignored while a page is already loading, so a fast
  /// scroll cannot fetch the same page twice or append it twice.
  Future<void> loadMore() async {
    final cursor = state.nextCursor;
    if (isClosed || cursor == null || state.loadingMore || state.status != LedgerStatus.ready) return;
    final generation = _generation;
    emit(
      LedgerState(status: LedgerStatus.ready, items: state.items, nextCursor: cursor, loadingMore: true),
    );
    final result = await _repository.ledger(cursor: cursor);
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) => emit(
        LedgerState(status: LedgerStatus.ready, items: state.items, nextCursor: cursor, moreFailure: failure),
      ),
      (page) => emit(
        LedgerState(status: LedgerStatus.ready, items: [...state.items, ...page.items], nextCursor: page.nextCursor),
      ),
    );
  }
}
