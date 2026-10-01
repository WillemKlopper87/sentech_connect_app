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

  /// Also the retry entry point.
  Future<void> load() async {
    emit(state.copyWith(status: PassesStatus.loading));
    final result = await _repository.getPasses(
      includeExpired: state.includeExpired,
    );
    if (isClosed) return;
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
