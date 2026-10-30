import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/app/router/app_router.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/change_plan_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/subscriber_failure_text.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// How the plan change screen was left, for the screen that opened it. The
/// opener refreshes the service when [changed] and then follows [route]: the
/// screen cannot push a route itself, because a route pushed from a page that
/// sits on top of the router's stack would land underneath it.
class ChangePlanExit {
  const ChangePlanExit({this.changed = false, this.route});

  final bool changed;
  final String? route;
}

/// Pick a plan, confirm, see what happened. Needs a [ChangePlanCubit] above it.
class ChangePlanPage extends StatelessWidget {
  const ChangePlanPage({super.key, this.clock});

  /// Test seam for "today".
  final DateTime Function()? clock;

  DateTime _today() => KycValidators.sastDate((clock ?? DateTime.now)());

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cubit = context.read<ChangePlanCubit>();
    return BlocBuilder<ChangePlanCubit, ChangePlanState>(
      builder: (context, state) {
        final busy = state.status == ChangePlanStatus.submitting;
        return PopScope(
          canPop: !busy,
          child: Scaffold(
            appBar: AppBar(title: Text(l10n.changePlanTitle)),
            body: SafeArea(child: _body(context, cubit, state)),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context, ChangePlanCubit cubit, ChangePlanState state) {
    switch (state.status) {
      case ChangePlanStatus.loadingPlans:
        return const Center(child: CircularProgressIndicator());
      case ChangePlanStatus.plansFailed:
        return FailureView(failure: state.failure, onRetry: cubit.loadPlans);
      case ChangePlanStatus.done:
        return _Result(state: state);
      case ChangePlanStatus.choosing:
      case ChangePlanStatus.submitting:
        final selected = state.selected;
        return selected == null
            ? _Picker(state: state)
            : _Confirm(plan: selected, state: state, today: _today());
    }
  }
}

class _Picker extends StatelessWidget {
  const _Picker({required this.state});

  final ChangePlanState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final service = context.read<ChangePlanCubit>().service;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.changePlanCurrent(service.planName), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (state.candidates.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 32),
            child: Text(l10n.changePlanEmpty, textAlign: TextAlign.center, style: theme.textTheme.bodyMedium),
          )
        else ...[
          Text(l10n.changePlanChoose, style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          for (final plan in state.candidates) ...[
            _PlanCard(plan: plan, onTap: () => context.read<ChangePlanCubit>().select(plan)),
            const SizedBox(height: 12),
          ],
        ],
      ],
    );
  }
}

class _PlanCard extends StatelessWidget {
  const _PlanCard({required this.plan, this.onTap});

  final SubscriberPlan plan;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: Key('plan-${plan.id}'),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: Text(plan.name, style: theme.textTheme.titleMedium)),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${l10n.servicePricePerMonth(formatRands(plan.priceCents))} · '
                '${l10n.serviceSpeeds(formatMbps(plan.downKbps), formatMbps(plan.upKbps))}',
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
              if (plan.kycRequired) ...[
                const SizedBox(height: 8),
                Chip(
                  label: Text(l10n.changePlanIdCheckNeeded),
                  avatar: const Icon(Icons.badge_outlined, size: 18),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Confirm extends StatelessWidget {
  const _Confirm({required this.plan, required this.state, required this.today});

  final SubscriberPlan plan;
  final ChangePlanState state;
  final DateTime today;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final cubit = context.read<ChangePlanCubit>();
    final busy = state.status == ChangePlanStatus.submitting;
    final sentence = switch (cubit.timingFor(plan)) {
      PlanChangeTiming.immediate => l10n.changeConfirmHigher,
      PlanChangeTiming.scheduled => l10n.changeConfirmLower(formatApiDay(context, firstOfNextMonth(today))),
      PlanChangeTiming.unknown => l10n.changeConfirmUnknown,
    };
    final failure = state.failure;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(l10n.changeConfirmTitle(plan.name), style: theme.textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          '${l10n.servicePricePerMonth(formatRands(plan.priceCents))} · '
          '${l10n.serviceSpeeds(formatMbps(plan.downKbps), formatMbps(plan.upKbps))}',
          style: theme.textTheme.bodyMedium,
        ),
        const SizedBox(height: 16),
        Text(sentence, key: const Key('change-sentence'), style: theme.textTheme.bodyLarge),
        if (failure != null) ...[
          const SizedBox(height: 16),
          Text(
            subscriberFailureText(l10n, failure),
            key: const Key('change-failure'),
            style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.error),
          ),
          if (failure is KycRequiredFailure) ...[
            const SizedBox(height: 8),
            OutlinedButton(
              key: const Key('change-id-check'),
              onPressed: () => Navigator.of(context).pop(const ChangePlanExit(route: AppRoutes.kyc)),
              child: Text(l10n.serviceActionIdCheck),
            ),
          ],
        ],
        const SizedBox(height: 24),
        FilledButton(
          key: const Key('change-confirm'),
          onPressed: busy ? null : cubit.confirm,
          child: Text(busy ? l10n.changeSubmitting : l10n.changeConfirmButton),
        ),
        const SizedBox(height: 8),
        TextButton(
          key: const Key('change-back'),
          onPressed: busy ? null : cubit.clearSelection,
          child: Text(l10n.changePlanChoose),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.state});

  final ChangePlanState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final change = state.result!;
    final planName = state.newPlan?.name ?? '';
    final date = formatApiDay(context, change.effectiveOn);
    final invoiceId = change.prorationInvoiceId;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(change.applied ? Icons.check_circle_outline : Icons.event_available_outlined, size: 48, color: theme.colorScheme.primary),
        const SizedBox(height: 16),
        Text(
          change.applied ? l10n.changeResultAppliedTitle : l10n.changeResultScheduledTitle,
          key: const Key('change-result-title'),
          textAlign: TextAlign.center,
          style: theme.textTheme.titleLarge,
        ),
        const SizedBox(height: 8),
        Text(
          change.applied ? l10n.changeResultAppliedBody(planName) : l10n.changeResultScheduledBody(date),
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        if (invoiceId != null) ...[
          FilledButton(
            key: const Key('change-view-invoice'),
            onPressed: () => Navigator.of(context).pop(ChangePlanExit(changed: true, route: AppRoutes.invoiceFor(invoiceId))),
            child: Text(l10n.changeResultViewInvoice),
          ),
          const SizedBox(height: 8),
        ],
        if (invoiceId == null)
          FilledButton(
            key: const Key('change-done'),
            onPressed: () => Navigator.of(context).pop(const ChangePlanExit(changed: true)),
            child: Text(l10n.commonDone),
          )
        else
          OutlinedButton(
            key: const Key('change-done'),
            onPressed: () => Navigator.of(context).pop(const ChangePlanExit(changed: true)),
            child: Text(l10n.commonDone),
          ),
      ],
    );
  }
}
