import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';

enum PassesStatus { loading, loaded, failure }

class PassesState extends Equatable {
  const PassesState({
    this.status = PassesStatus.loading,
    this.passes = const [],
    this.includeExpired = false,
    this.failure,
  });

  final PassesStatus status;
  final List<Pass> passes;
  final bool includeExpired;
  final Failure? failure;

  PassesState copyWith({
    PassesStatus? status,
    List<Pass>? passes,
    bool? includeExpired,
    Failure? failure,
  }) => PassesState(
    status: status ?? this.status,
    passes: passes ?? this.passes,
    includeExpired: includeExpired ?? this.includeExpired,
    failure: failure,
  );

  @override
  List<Object?> get props => [status, passes, includeExpired, failure];
}

class PassesCubit extends Cubit<PassesState> {
  PassesCubit(this._repository) : super(const PassesState()) {
    load();
  }

  final PassesRepository _repository;
  var _generation = 0;

  /// Also the retry and pull-to-refresh entry point. Visible passes stay on
  /// screen while refreshing; only an empty screen shows the spinner. Only the
  /// newest request may publish, so out-of-order responses are dropped.
  Future<void> load() async {
    final generation = ++_generation;
    emit(
      state.copyWith(
        status: state.passes.isEmpty || state.status == PassesStatus.failure
            ? PassesStatus.loading
            : state.status,
      ),
    );
    final result = await _repository.getPasses(
      includeExpired: state.includeExpired,
    );
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) =>
          emit(state.copyWith(status: PassesStatus.failure, failure: failure)),
      (passes) =>
          emit(state.copyWith(status: PassesStatus.loaded, passes: passes)),
    );
  }

  Future<void> setIncludeExpired(bool value) async {
    emit(state.copyWith(includeExpired: value));
    await load();
  }
}
