import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/subscriber_plans_repository.dart';

enum PlansStatus { loading, loaded, failure }

class PlansState extends Equatable {
  const PlansState({this.status = PlansStatus.loading, this.plans = const [], this.failure});

  final PlansStatus status;

  /// Grouped by kind (home hotspot first, then fixed wireless), cheapest first
  /// inside each group.
  final List<SubscriberPlan> plans;
  final Failure? failure;

  List<SubscriberPlan> ofKind(SubscriberPlanKind kind) => [for (final p in plans) if (p.kind == kind) p];

  SubscriberPlan? byId(String id) {
    for (final p in plans) {
      if (p.id == id) return p;
    }
    return null;
  }

  @override
  List<Object?> get props => [status, plans, failure];
}

/// The tenant's monthly plans. Public data, so it loads before an account
/// exists. Sorting is the only thing the app does to the API's list.
class PlansCubit extends Cubit<PlansState> {
  PlansCubit(this._repository) : super(const PlansState()) {
    load();
  }

  final SubscriberPlansRepository _repository;

  Future<void> load({bool keepVisible = false}) async {
    if (!keepVisible || state.status != PlansStatus.loaded) emit(const PlansState());
    final result = await _repository.list();
    if (isClosed) return;
    result.match(
      (failure) {
        if (keepVisible && state.status == PlansStatus.loaded) return;
        emit(PlansState(status: PlansStatus.failure, failure: failure));
      },
      (plans) => emit(PlansState(status: PlansStatus.loaded, plans: sortPlans(plans))),
    );
  }
}

/// Kind groups in a fixed order, price ascending inside a group; ties keep
/// the API order (the sort is stable).
List<SubscriberPlan> sortPlans(List<SubscriberPlan> plans) {
  final indexed = [for (var i = 0; i < plans.length; i++) (i, plans[i])];
  indexed.sort((a, b) {
    final byKind = a.$2.kind.index.compareTo(b.$2.kind.index);
    if (byKind != 0) return byKind;
    final byPrice = a.$2.priceCents.compareTo(b.$2.priceCents);
    return byPrice != 0 ? byPrice : a.$1.compareTo(b.$1);
  });
  return [for (final e in indexed) e.$2];
}
