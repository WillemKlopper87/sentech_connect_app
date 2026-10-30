import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/plans_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/plan_facts.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Every fact about one plan, and the way on to sign-up. The plan comes from
/// the list a [PlansCubit] above this page loaded (ids are never passed
/// through `extra`).
class PlanDetailPage extends StatelessWidget {
  const PlanDetailPage({super.key, required this.planId, required this.onChoose, required this.onBackToPlans});

  final String planId;
  final void Function(SubscriberPlan plan) onChoose;
  final VoidCallback onBackToPlans;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.planDetailTitle)),
      body: SafeArea(
        child: BlocBuilder<PlansCubit, PlansState>(
          builder: (context, state) {
            if (state.status == PlansStatus.loading) return const Center(child: CircularProgressIndicator());
            if (state.status == PlansStatus.failure) {
              return FailureView(failure: state.failure, onRetry: context.read<PlansCubit>().load);
            }
            final plan = state.byId(planId);
            if (plan == null) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(l10n.failurePlanUnavailable, key: const Key('plan-missing'), textAlign: TextAlign.center),
                      const SizedBox(height: 12),
                      OutlinedButton(onPressed: onBackToPlans, child: Text(l10n.planBackToPlans)),
                    ],
                  ),
                ),
              );
            }
            return _Body(plan: plan, onChoose: () => onChoose(plan));
          },
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.plan, required this.onChoose});

  final SubscriberPlan plan;
  final VoidCallback onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final lines = <String>[
      planSpeedLine(context, plan),
      ?planBurstLine(context, plan),
      ...planFairUseLines(context, plan),
      l10n.planDevices(plan.maxDevices),
      if (plan.setupFeeCents > 0) l10n.planSetupFee(formatRands(plan.setupFeeCents)),
    ];
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(plan.name, style: theme.textTheme.headlineSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [PlanKindChip(plan.kind), if (plan.kycRequired) const PlanIdCheckChip()],
        ),
        const SizedBox(height: 12),
        Text(planPriceLine(context, plan), style: theme.textTheme.titleLarge),
        if (plan.description.trim().isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(plan.description, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 16),
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.check, size: 18),
                const SizedBox(width: 8),
                Expanded(child: Text(line, style: theme.textTheme.bodyMedium)),
              ],
            ),
          ),
        const SizedBox(height: 20),
        FilledButton(key: const Key('plan-choose'), onPressed: onChoose, child: Text(l10n.planChoose)),
      ],
    );
  }
}
