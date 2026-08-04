import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/bloc/account_cubit.dart';
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
  });

  final VoidCallback onTopUp;
  final VoidCallback onUpgrade;
  final VoidCallback onReportIssue;
  final VoidCallback onOpenPromotions;

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
        actions: const [Padding(padding: EdgeInsets.only(right: 16), child: Icon(Icons.notifications_none))],
      ),
      body: BlocBuilder<AccountCubit, AccountState>(
        builder: (context, state) {
          if (state.status != AccountStatus.loaded || state.summary == null) {
            return const Center(child: CircularProgressIndicator());
          }
          final summary = state.summary!;
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
            children: [
              _UsageCard(summary: summary),
              const SizedBox(height: 16),
              _PromoBanner(onTap: onOpenPromotions),
              const SizedBox(height: 16),
              _CpeCard(summary: summary),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: _QuickAction(label: 'Top up', onTap: onTopUp)),
                  const SizedBox(width: 8),
                  Expanded(child: _QuickAction(label: 'Upgrade', onTap: onUpgrade)),
                  const SizedBox(width: 8),
                  Expanded(child: _QuickAction(label: 'Report issue', onTap: onReportIssue)),
                ],
              ),
            ],
          );
        },
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
                    backgroundColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
                    color: theme.colorScheme.primary,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('${(summary.usageFraction * 100).round()}%', style: theme.textTheme.titleMedium),
                    Text('USED', style: theme.textTheme.bodyMedium?.copyWith(fontSize: 9)),
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
                Text('${summary.usedGB.toStringAsFixed(0)}GB of ${summary.totalGB.toStringAsFixed(0)}GB',
                    style: theme.textTheme.titleMedium),
                Text('${summary.planName} · renews ${summary.renewsOn}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
          Icon(Icons.router_outlined, color: theme.colorScheme.primary, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(summary.routerName, style: theme.textTheme.titleMedium),
                Text('MAC •• •• ${summary.macAddressSuffix}',
                    style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
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
                  color: active ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
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
          gradient: const LinearGradient(colors: [Color(0xFF00335C), Color(0xFF00ACC6)]),
          borderRadius: BorderRadius.circular(14),
        ),
        child: const Row(
          children: [
            Icon(Icons.workspace_premium_outlined, color: Colors.white, size: 24),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Promotions & loyalty — see what\'s on offer',
                style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
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
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(label, textAlign: TextAlign.center, style: theme.textTheme.labelLarge),
      ),
    );
  }
}
