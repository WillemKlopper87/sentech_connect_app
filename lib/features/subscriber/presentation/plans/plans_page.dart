import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/plans_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/plans/plan_facts.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The monthly plans, grouped by kind, cheapest first. Needs a [PlansCubit]
/// above it; [onOpenPlan] opens the plan's detail.
class PlansPage extends StatelessWidget {
  const PlansPage({super.key, required this.onOpenPlan});

  final void Function(SubscriberPlan plan) onOpenPlan;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.plansTitle)),
      body: SafeArea(
        child: BlocBuilder<PlansCubit, PlansState>(
          builder: (context, state) {
            switch (state.status) {
              case PlansStatus.loading:
                return const Center(child: CircularProgressIndicator());
              case PlansStatus.failure:
                return FailureView(failure: state.failure, onRetry: context.read<PlansCubit>().load);
              case PlansStatus.loaded:
                return RefreshIndicator(
                  onRefresh: () => context.read<PlansCubit>().load(keepVisible: true),
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(20),
                    children: [
                      if (state.plans.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 48),
                          child: Text(
                            l10n.plansEmpty,
                            key: const Key('plans-empty'),
                            textAlign: TextAlign.center,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ),
                      for (final plan in state.plans) ...[
                        PlanCard(plan: plan, onTap: () => onOpenPlan(plan)),
                        const SizedBox(height: 12),
                      ],
                    ],
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}

/// One plan: name, kind and ID-check chips, price, speeds, setup fee.
class PlanCard extends StatelessWidget {
  const PlanCard({super.key, required this.plan, required this.onTap});

  final SubscriberPlan plan;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(plan.name, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [PlanKindChip(plan.kind), if (plan.kycRequired) const PlanIdCheckChip()],
              ),
              const SizedBox(height: 8),
              Text(planPriceLine(context, plan), style: theme.textTheme.titleSmall),
              Text(planSpeedLine(context, plan), style: muted),
              if (plan.setupFeeCents > 0) Text(l10n.planSetupFee(formatRands(plan.setupFeeCents)), style: muted),
            ],
          ),
        ),
      ),
    );
  }
}
