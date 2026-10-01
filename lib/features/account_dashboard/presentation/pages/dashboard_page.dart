import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/bloc/account_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Note: the concept walkthrough showed this screen in dark mode to
/// demonstrate the brand's dark-navy treatment (docs/brand-tokens.md).
/// The real screen follows the system theme like every other screen —
/// AppTheme.dark() supplies that look automatically when the OS is dark,
/// nothing here is hardcoded to one mode.
class DashboardPage extends StatelessWidget {
  const DashboardPage({
    super.key,
    required this.onTopUp,
    required this.onUpgrade,
    required this.onReportIssue,
    required this.onOpenPromotions,
    required this.onResumeOrder,
  });

  final VoidCallback onTopUp;
  final VoidCallback onUpgrade;
  final VoidCallback onReportIssue;
  final VoidCallback onOpenPromotions;
  final void Function(Order order) onResumeOrder;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            const SentechLogo(height: 20),
            const SizedBox(width: 10),
            const Text('Dashboard'),
          ],
        ),
        actions: const [
          Padding(
            padding: EdgeInsets.only(right: 16),
            child: Icon(Icons.notifications_none),
          ),
        ],
      ),
      body: BlocBuilder<AccountCubit, AccountState>(
        builder: (context, state) {
          if (state.status == AccountStatus.failure) {
            return FailureView(
              failure: state.failure,
              onRetry: () => context.read<AccountCubit>().load(),
            );
          }
          if (state.status != AccountStatus.loaded || state.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = state.summary!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              BlocBuilder<OpenOrderCubit, Order?>(
                builder: (context, order) {
                  if (order == null) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: _ResumeOrderBanner(
                      order: order,
                      onTap: () => onResumeOrder(order),
                    ),
                  );
                },
              ),
              _UsageCard(summary: summary),
              const SizedBox(height: 16),
              _PromoBanner(onTap: onOpenPromotions),
              const SizedBox(height: 16),
              _CpeCard(summary: summary),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _QuickAction(label: 'Top up', onTap: onTopUp),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(label: 'Upgrade', onTap: onUpgrade),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _QuickAction(
                      label: 'Report issue',
                      onTap: onReportIssue,
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Resume point for an unpaid order: "verify your identity" before RICA,
/// "complete payment" after it. Survives app restarts because the order is
/// persisted by the checkout repository.
class _ResumeOrderBanner extends StatelessWidget {
  const _ResumeOrderBanner({required this.order, required this.onTap});

  final Order order;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final needsVerification = order.status == OrderStatus.pendingVerification;
    return Material(
      color: theme.colorScheme.primary.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                needsVerification
                    ? Icons.verified_user_outlined
                    : Icons.payment,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Finish your order #${order.orderNumber}',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      switch (order.status) {
                        OrderStatus.pendingVerification =>
                          'Verify your identity to continue',
                        OrderStatus.paymentFailed =>
                          'Your last payment did not go through. Try again.',
                        _ => 'Complete your payment',
                      },
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.summary});

  final AccountSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 84,
            height: 84,
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 84,
                  height: 84,
                  child: CircularProgressIndicator(
                    value: summary.usageFraction,
                    strokeWidth: 8,
                    backgroundColor: theme.colorScheme.outlineVariant
                        .withValues(alpha: 0.4),
                    color: theme.colorScheme.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '${(summary.usageFraction * 100).round()}%',
                      style: theme.textTheme.titleMedium,
                    ),
                    Text(
                      'USED',
                      style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${summary.usedGB.toStringAsFixed(0)}GB of ${summary.totalGB.toStringAsFixed(0)}GB',
                  style: theme.textTheme.titleMedium,
                ),
                Text(
                  '${summary.planName} · renews ${summary.renewsOn}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CpeCard extends StatelessWidget {
  const _CpeCard({required this.summary});

  final AccountSummary summary;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(
            Icons.router_outlined,
            color: theme.colorScheme.primary,
            size: 28,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.routerName, style: theme.textTheme.titleMedium),
                Text(
                  'MAC •• •• ${summary.macAddressSuffix}',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(4, (i) {
              final active = i < summary.signalBars;
              return Container(
                width: 3,
                height: 6.0 + i * 3,
                margin: const EdgeInsets.only(left: 2),
                decoration: BoxDecoration(
                  color: active
                      ? theme.colorScheme.primary
                      : theme.colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(1),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

class _PromoBanner extends StatelessWidget {
  const _PromoBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Color(0xFF00335C), Color(0xFF00ACC6)],
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(
              Icons.workspace_premium_outlined,
              color: Colors.white,
              size: 24,
            ),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Promotions & loyalty — see what\'s on offer',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
            Icon(Icons.chevron_right, color: Colors.white70, size: 20),
          ],
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        // 48dp minimum touch target.
        constraints: const BoxConstraints(minHeight: 48),
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
      ),
    );
  }
}
