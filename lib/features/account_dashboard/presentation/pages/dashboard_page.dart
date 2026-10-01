import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/account_dashboard/domain/entities/account_summary.dart';
import 'package:sentech_connect_app/features/account_dashboard/presentation/bloc/account_cubit.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/order_cubit.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_format.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
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
    this.onBuyPass,
    this.onOpenPasses,
    this.showRouterCard = true,
    this.onReportIssue,
    required this.onOpenPromotions,
    required this.onResumeOrder,
  });

  final VoidCallback onTopUp;
  final VoidCallback onUpgrade;

  /// Opens the Shop on hotspot passes. When set, the dashboard leads with the
  /// customer's current pass (it needs a [PassesCubit] above it).
  final VoidCallback? onBuyPass;
  final VoidCallback? onOpenPasses;

  /// The tenant's `cpe` flag. Off: no router card, no fixed-plan usage, no
  /// Upgrade shortcut; the dashboard is about hotspot passes only.
  final bool showRouterCard;
  /// Null hides the shortcut (support tickets are mock-backed in prod).
  final VoidCallback? onReportIssue;
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
      body: showRouterCard ? _withAccount(context) : _content(context, null),
    );
  }

  /// Fixed-plan content needs the account summary; hotspot-only does not.
  Widget _withAccount(BuildContext context) {
    return BlocBuilder<AccountCubit, AccountState>(
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
        return _content(context, state.summary!);
      },
    );
  }

  Widget _content(BuildContext context, AccountSummary? summary) {
    return RefreshIndicator(
      onRefresh: () async {
        if (onOpenPasses != null) await context.read<PassesCubit>().load();
        if (showRouterCard && context.mounted) {
          await context.read<AccountCubit>().load();
        }
      },
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
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
          if (onOpenPasses case final openPasses?) ...[
            _CurrentPassCard(
              onOpenPasses: openPasses,
              onBuyPass: onBuyPass ?? onTopUp,
            ),
            const SizedBox(height: 16),
          ],
          if (summary != null) ...[
            _UsageCard(summary: summary),
            const SizedBox(height: 16),
          ],
          _PromoBanner(onTap: onOpenPromotions),
          const SizedBox(height: 16),
          // Router telemetry needs the CPE/ACS integration (flag `cpe`, off at launch).
          if (showRouterCard && summary != null) ...[
            _CpeCard(summary: summary),
            const SizedBox(height: 16),
          ],
          Row(
            children: [
              Expanded(
                child: _QuickAction(
                  label: onBuyPass != null
                      ? context.l10n.dashboardBuyPass
                      : context.l10n.dashboardTopUp,
                  onTap: onBuyPass ?? onTopUp,
                ),
              ),
              const SizedBox(width: 8),
              if (showRouterCard) ...[
                Expanded(
                  child: _QuickAction(label: context.l10n.dashboardUpgrade, onTap: onUpgrade),
                ),
                const SizedBox(width: 8),
              ],
              if (onReportIssue case final reportIssue?)
                Expanded(
                  child: _QuickAction(
                    label: context.l10n.dashboardReportIssue,
                    onTap: reportIssue,
                  ),
                ),
            ],
          ),
        ],
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

/// The customer's current hotspot pass (active first, else the next
/// scheduled one) with time and data remaining, plus a "Buy a pass" action.
/// A failed load shows an error with Retry, never "no pass".
class _CurrentPassCard extends StatefulWidget {
  const _CurrentPassCard({required this.onOpenPasses, required this.onBuyPass});

  final VoidCallback onOpenPasses;
  final VoidCallback onBuyPass;

  @override
  State<_CurrentPassCard> createState() => _CurrentPassCardState();
}

class _CurrentPassCardState extends State<_CurrentPassCard> {
  /// Re-renders the time left once a minute while the dashboard is alive.
  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    return BlocBuilder<PassesCubit, PassesState>(
      builder: (context, state) {
        final current =
            state.passes
                .where((p) => p.status == PassStatus.active)
                .firstOrNull ??
            state.passes
                .where((p) => p.status == PassStatus.scheduled)
                .firstOrNull;
        final failed = state.status == PassesStatus.failure && current == null;
        final loading = state.status == PassesStatus.loading && current == null;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (loading)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(8),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (failed)
                FailureView(
                  failure: state.failure,
                  compact: true,
                  onRetry: () => context.read<PassesCubit>().load(),
                )
              else if (current == null) ...[
                Text(l10n.dashboardNoPass, style: theme.textTheme.titleMedium),
                Text(
                  l10n.dashboardNoPassHint,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ] else
                ..._passDetails(context, current),
              if (!failed) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        onPressed: widget.onBuyPass,
                        child: Text(l10n.dashboardBuyPass),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: widget.onOpenPasses,
                        child: Text(l10n.dashboardMyPasses),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  List<Widget> _passDetails(BuildContext context, Pass current) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final dataLeft = dataLeftText(l10n, current);
    final fraction = current.dataUsedFraction;
    return [
      Row(
        children: [
          Expanded(
            child: Text(
              current.productName,
              style: theme.textTheme.titleMedium,
            ),
          ),
          Text(
            current.status == PassStatus.active
                ? l10n.passesStatusActive
                : l10n.passesStatusScheduled,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.primary,
            ),
          ),
        ],
      ),
      const SizedBox(height: 4),
      Text(
        current.status == PassStatus.active
            ? l10n.dashboardTimeLeft(
                formatTimeLeft(
                  l10n,
                  current.expiresAt.difference(DateTime.now().toUtc()),
                ),
              )
            : l10n.passesStarts(
                DateFormat.MMMd(
                  Localizations.localeOf(context).toLanguageTag(),
                ).add_Hm().format(current.startsAt.toLocal()),
              ),
        style: theme.textTheme.bodyMedium,
      ),
      if (dataLeft != null) ...[
        Text(
          dataLeft,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        // A zero cap has no meaningful bar: show the text only.
        if (fraction != null) ...[
          const SizedBox(height: 10),
          LinearProgressIndicator(value: fraction),
        ],
      ] else
        Text(
          l10n.dashboardUncapped,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
    ];
  }
}
