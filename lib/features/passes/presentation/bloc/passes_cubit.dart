// ignore_for_file: prefer_initializing_formals

import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/domain/repositories/passes_repository.dart';
import 'package:sentech_connect_app/features/passes/domain/usage_alert_scheduler.dart';

enum PassesStatus { loading, loaded, failure }

class PassesState extends Equatable {
  const PassesState({
    this.status = PassesStatus.loading,
    this.passes = const [],
    this.includeExpired = false,
    this.failure,
    this.loadedAt,
    this.fromCache = false,
  });

  final PassesStatus status;
  final List<Pass> passes;
  final bool includeExpired;
  final Failure? failure;
  final DateTime? loadedAt;
  final bool fromCache;

  PassesState copyWith({
    PassesStatus? status,
    List<Pass>? passes,
    bool? includeExpired,
    Failure? failure,
    DateTime? loadedAt,
    bool? fromCache,
  }) => PassesState(
    status: status ?? this.status,
    passes: passes ?? this.passes,
    includeExpired: includeExpired ?? this.includeExpired,
    failure: failure,
    loadedAt: loadedAt ?? this.loadedAt,
    fromCache: fromCache ?? this.fromCache,
  );

  @override
  List<Object?> get props => [
    status,
    passes,
    includeExpired,
    failure,
    loadedAt,
    fromCache,
  ];
}

class PassesCubit extends Cubit<PassesState> {
  PassesCubit(this._repository, {UsageAlertCoordinator? alerts})
    : _alerts = alerts,
      super(const PassesState()) {
    load();
  }

  final PassesRepository _repository;
  final UsageAlertCoordinator? _alerts;
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
    final result = await _repository.getPassLoad(
      includeExpired: state.includeExpired,
    );
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) =>
          emit(state.copyWith(status: PassesStatus.failure, failure: failure)),
      (load) {
        emit(
          state.copyWith(
            status: PassesStatus.loaded,
            passes: load.passes,
            loadedAt: load.loadedAt,
            fromCache: load.fromCache,
          ),
        );
        final alerts = _alerts;
        if (!load.fromCache && alerts != null) {
          unawaited(alerts.onLoaded(load.passes).catchError((Object _) {}));
        }
      },
    );
  }

  Future<void> setIncludeExpired(bool value) async {
    emit(state.copyWith(includeExpired: value));
    await load();
  }
}
