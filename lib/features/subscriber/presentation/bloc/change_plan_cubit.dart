import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/network/idempotency.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';

enum ChangePlanStatus { loadingPlans, plansFailed, choosing, submitting, done }

class ChangePlanState extends Equatable {
  const ChangePlanState({
    this.status = ChangePlanStatus.loadingPlans,
    this.candidates = const [],
    this.selected,
    this.failure,
    this.result,
    this.newPlan,
  });

  final ChangePlanStatus status;

  /// Plans the service can move to: active, the same kind, not the current
  /// plan, cheapest first.
  final List<SubscriberPlan> candidates;

  /// The plan whose confirmation is showing, or null while picking.
  final SubscriberPlan? selected;

  /// Why the plans did not load, or why the last confirm was refused.
  final Failure? failure;

  /// What the platform did (set when [status] is done).
  final PlanChange? result;

  /// The plan that was confirmed (set when [status] is done).
  final SubscriberPlan? newPlan;

  ChangePlanState copyWith({
    ChangePlanStatus? status,
    List<SubscriberPlan>? candidates,
    SubscriberPlan? selected,
    bool clearSelected = false,
    Failure? failure,
    PlanChange? result,
    SubscriberPlan? newPlan,
  }) => ChangePlanState(
    status: status ?? this.status,
    candidates: candidates ?? this.candidates,
    selected: clearSelected ? null : (selected ?? this.selected),
    failure: failure,
    result: result ?? this.result,
    newPlan: newPlan ?? this.newPlan,
  );

  @override
  List<Object?> get props => [status, candidates, selected, failure, result, newPlan];
}

/// Plan picker and confirm for one service. The `Idempotency-Key` belongs to
/// the (service, chosen plan) attempt: a retry after a failed or lost answer
/// reuses it, choosing another plan gets a new one.
class ChangePlanCubit extends Cubit<ChangePlanState> {
  ChangePlanCubit(this._repository, this._plans, this.service, {String Function()? newKey})
    : _newKey = newKey ?? newIdempotencyKey,
      super(const ChangePlanState()) {
    loadPlans();
  }

  final SubscriberRepository _repository;
  final SubscriberPlansRepository _plans;
  final SubscriberService service;
  final String Function() _newKey;
  String? _key;

  Future<void> loadPlans() async {
    emit(const ChangePlanState());
    final result = await _plans.list();
    if (isClosed) return;
    result.match(
      (failure) => emit(ChangePlanState(status: ChangePlanStatus.plansFailed, failure: failure)),
      (plans) => emit(ChangePlanState(status: ChangePlanStatus.choosing, candidates: candidatesFor(service, plans))),
    );
  }

  /// Same kind only (the platform answers 409 `plan_kind_mismatch` otherwise),
  /// not the plan the service is on, cheapest first.
  static List<SubscriberPlan> candidatesFor(SubscriberService service, List<SubscriberPlan> plans) {
    final list = [for (final p in plans) if (p.kind == service.kind && p.id != service.planId) p];
    list.sort((a, b) => a.priceCents.compareTo(b.priceCents));
    return list;
  }

  /// What the confirm sentence should promise for [plan].
  PlanChangeTiming timingFor(SubscriberPlan plan) =>
      planChangeTiming(currentPriceCents: service.priceCents, newPriceCents: plan.priceCents);

  void select(SubscriberPlan plan) {
    if (state.status != ChangePlanStatus.choosing) return;
    _key = _newKey();
    emit(state.copyWith(selected: plan));
  }

  void clearSelection() {
    if (state.status != ChangePlanStatus.choosing) return;
    _key = null;
    emit(state.copyWith(clearSelected: true));
  }

  Future<void> confirm() async {
    final plan = state.selected;
    if (plan == null || state.status == ChangePlanStatus.submitting) return;
    final key = _key ??= _newKey();
    emit(state.copyWith(status: ChangePlanStatus.submitting));
    final result = await _repository.changePlan(service.id, plan.id, idempotencyKey: key);
    if (isClosed) return;
    result.match(
      (failure) => emit(state.copyWith(status: ChangePlanStatus.choosing, failure: failure)),
      (change) => emit(state.copyWith(status: ChangePlanStatus.done, result: change, newPlan: plan)),
    );
  }
}
