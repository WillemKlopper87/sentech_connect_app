import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/domain/repositories/credits_repository.dart';

enum CreditsStatus { loading, ready, unavailable, error }

class CreditsState extends Equatable {
  const CreditsState({this.status = CreditsStatus.loading, this.summary, this.failure});

  final CreditsStatus status;
  final CreditsSummary? summary;
  final Failure? failure;

  @override
  List<Object?> get props => [status, summary, failure];
}

/// The wallet. `unavailable` means the provider has rewards off or the server
/// does not have them: the screens hide the feature, they do not show an error.
/// A refresh keeps the last wallet on screen when it fails.
class CreditsCubit extends Cubit<CreditsState> {
  CreditsCubit(this._repository) : super(const CreditsState()) {
    load();
  }

  final CreditsRepository _repository;
  int _generation = 0;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    if (!keepVisible || state.summary == null) emit(const CreditsState());
    final result = await _repository.summary();
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) {
        if (failure is CreditsNotAvailableFailure) {
          emit(CreditsState(status: CreditsStatus.unavailable, failure: failure));
        } else if (!(keepVisible && state.summary != null)) {
          emit(CreditsState(status: CreditsStatus.error, failure: failure));
        }
      },
      (summary) => emit(CreditsState(status: CreditsStatus.ready, summary: summary)),
    );
  }

  /// Pull to refresh, the retry button, and after a redeem or a check-in.
  Future<void> refresh() => load(keepVisible: true);
}
