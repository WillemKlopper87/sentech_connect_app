import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/repositories/fiveg_repository.dart';

enum FiveGUsageStatus { loading, loaded, unavailable, failure }

class FiveGUsageState extends Equatable {
  const FiveGUsageState({
    this.status = FiveGUsageStatus.loading,
    this.usage,
    this.failure,
    this.restoringTimedOut = false,
  });

  final FiveGUsageStatus status;
  final FiveGUsage? usage;
  final Failure? failure;

  /// The restore did not finish inside the polling window: the screen says
  /// "Pull to refresh" instead of polling forever.
  final bool restoringTimedOut;

  @override
  List<Object?> get props => [status, usage, failure, restoringTimedOut];
}

/// Ten seconds between checks, 18 checks: three minutes after an unlock is
/// paid, which covers the background job that restores the service.
final defaultRestoringPollDelays = List<Duration>.filled(18, const Duration(seconds: 10));

/// The data allowance of one service. While an unlock is being applied
/// (`restoring`), it polls with [restoringPollDelays] and then stops.
class FiveGUsageCubit extends Cubit<FiveGUsageState> {
  FiveGUsageCubit(
    this._repository,
    this.serviceId, {
    List<Duration>? restoringPollDelays,
    Future<void> Function(Duration)? wait,
  }) : _restoringPollDelays = restoringPollDelays ?? defaultRestoringPollDelays,
       _wait = wait ?? ((d) => Future<void>.delayed(d)),
       super(const FiveGUsageState()) {
    load();
  }

  final FiveGRepository _repository;
  final String serviceId;
  final List<Duration> _restoringPollDelays;
  final Future<void> Function(Duration) _wait;

  /// Each load starts a new generation; an older poll loop stops when it sees
  /// that its generation is no longer current.
  int _generation = 0;

  Future<void> load({bool keepVisible = false}) async {
    final generation = ++_generation;
    if (!keepVisible || state.usage == null) emit(const FiveGUsageState());
    final result = await _repository.getUsage(serviceId);
    if (isClosed || generation != _generation) return;
    result.match(
      (failure) {
        if (failure is FiveGNotAvailableFailure) {
          emit(FiveGUsageState(status: FiveGUsageStatus.unavailable, failure: failure));
        } else if (!(keepVisible && state.usage != null)) {
          emit(FiveGUsageState(status: FiveGUsageStatus.failure, failure: failure));
        }
      },
      (usage) => emit(FiveGUsageState(status: FiveGUsageStatus.loaded, usage: usage)),
    );
    if (state.usage?.restoring ?? false) await _pollUntilRestored(generation);
  }

  /// Pull to refresh and the retry button.
  Future<void> refresh() => load(keepVisible: true);

  Future<void> _pollUntilRestored(int generation) async {
    for (final delay in _restoringPollDelays) {
      await _wait(delay);
      if (isClosed || generation != _generation) return;
      final result = await _repository.getUsage(serviceId);
      if (isClosed || generation != _generation) return;
      final usage = result.match((_) => null, (u) => u);
      // A failed check keeps the last answer and tries again on the next tick.
      if (usage == null) continue;
      emit(FiveGUsageState(status: FiveGUsageStatus.loaded, usage: usage));
      if (!usage.restoring) return;
    }
    if (isClosed || generation != _generation) return;
    emit(FiveGUsageState(status: FiveGUsageStatus.loaded, usage: state.usage, restoringTimedOut: true));
  }
}
