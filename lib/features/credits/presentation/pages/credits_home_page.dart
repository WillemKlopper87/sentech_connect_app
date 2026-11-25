import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/credits_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/credits_text.dart';
import 'package:sentech_connect_app/features/credits/presentation/widgets/credits_notice.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The Rewards home: the wallet (available and on hold shown separately), the
/// credits about to expire when the server says so, the streak and tier, and
/// the way to every function. Needs a [CreditsCubit] above it. Frozen and
/// capped wallets are explained in words and the redeem row is disabled.
/// Everything shown is the server's number; nothing is estimated here.
class CreditsHomePage extends StatelessWidget {
  const CreditsHomePage({
    super.key,
    required this.onOpenRedeem,
    required this.onOpenStreak,
    required this.onOpenMissions,
    required this.onOpenBadges,
    required this.onOpenLedger,
  });

  final VoidCallback onOpenRedeem;
  final VoidCallback onOpenStreak;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenBadges;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsTitle)),
      body: SafeArea(
        child: BlocBuilder<CreditsCubit, CreditsState>(
          builder: (context, state) => switch (state.status) {
            CreditsStatus.loading => const Center(child: CircularProgressIndicator()),
            CreditsStatus.unavailable => CreditsMessage(l10n.creditsUnavailable),
            CreditsStatus.error => FailureView(
              failure: state.failure,
              onRetry: () => context.read<CreditsCubit>().refresh(),
            ),
            CreditsStatus.ready => RefreshIndicator(
              onRefresh: () => context.read<CreditsCubit>().refresh(),
              child: _Loaded(
                summary: state.summary!,
                onOpenRedeem: onOpenRedeem,
                onOpenStreak: onOpenStreak,
                onOpenMissions: onOpenMissions,
                onOpenBadges: onOpenBadges,
                onOpenLedger: onOpenLedger,
              ),
            ),
          },
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({
    required this.summary,
    required this.onOpenRedeem,
    required this.onOpenStreak,
    required this.onOpenMissions,
    required this.onOpenBadges,
    required this.onOpenLedger,
  });

  final CreditsSummary summary;
  final VoidCallback onOpenRedeem;
  final VoidCallback onOpenStreak;
  final VoidCallback onOpenMissions;
  final VoidCallback onOpenBadges;
  final VoidCallback onOpenLedger;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final tier = tierName(l10n, summary.tier);
    final streak = summary.streak;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (summary.frozen) ...[CreditsNotice(text: l10n.creditsFrozenNotice, warning: true), const SizedBox(height: 12)],
        if (!summary.frozen && summary.caps.monthlyEarnLimitReached) ...[
          CreditsNotice(text: l10n.creditsMonthlyLimitNotice),
          const SizedBox(height: 12),
        ],
        if (summary.expiring30d > 0) ...[
          CreditsNotice(text: l10n.creditsExpiringBanner(l10n.creditsAmount(summary.expiring30d))),
          const SizedBox(height: 12),
        ],
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.creditsHomeAvailable, style: theme.textTheme.labelLarge),
                const SizedBox(height: 4),
                Text(
                  l10n.creditsAmount(summary.available),
                  key: const Key('credits-available'),
                  style: theme.textTheme.headlineMedium,
                ),
                if (summary.pending > 0) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.creditsHomePending(l10n.creditsAmount(summary.pending)),
                    key: const Key('credits-pending'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
                if (streak != null || tier != null) ...[
                  const SizedBox(height: 12),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (streak != null && streak > 0)
                        Chip(
                          avatar: const Icon(Icons.local_fire_department_outlined, size: 18),
                          label: Text(l10n.creditsStreakChip(l10n.creditsDaysCount(streak))),
                        ),
                      if (tier != null)
                        Chip(
                          avatar: const Icon(Icons.workspace_premium_outlined, size: 18),
                          label: Text(l10n.creditsTierChip(tier)),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          l10n.creditsTermsLine(summary.rates.expiryDays.toString()),
          key: const Key('credits-terms'),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 16),
        _Tile(
          icon: Icons.data_usage,
          title: l10n.creditsTileRedeem,
          subtitle: l10n.creditsTileRedeemHint,
          // A frozen wallet cannot spend: the row is shown but cannot be opened.
          onTap: summary.frozen ? null : onOpenRedeem,
          tileKey: const Key('credits-tile-redeem'),
        ),
        _Tile(
          icon: Icons.event_available_outlined,
          title: l10n.creditsTileCheckIn,
          subtitle: l10n.creditsTileCheckInHint,
          onTap: onOpenStreak,
          tileKey: const Key('credits-tile-checkin'),
        ),
        _Tile(icon: Icons.flag_outlined, title: l10n.creditsTileMissions, onTap: onOpenMissions),
        _Tile(icon: Icons.military_tech_outlined, title: l10n.creditsTileBadges, onTap: onOpenBadges),
        _Tile(icon: Icons.history, title: l10n.creditsTileHistory, onTap: onOpenLedger),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: () => _showHow(context, summary.rates),
          icon: const Icon(Icons.help_outline),
          label: Text(l10n.creditsHowTitle),
        ),
      ],
    );
  }

  void _showHow(BuildContext context, CreditRates rates) {
    final l10n = context.l10n;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l10n.creditsHowTitle, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              Text(l10n.creditsHowBody(rates.expiryDays.toString(), rates.mbPerCredit.toString())),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, this.subtitle, required this.onTap, this.tileKey});

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback? onTap;
  final Key? tileKey;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(color: Theme.of(context).colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          key: tileKey,
          minTileHeight: 56,
          enabled: onTap != null,
          leading: Icon(icon),
          title: Text(title),
          subtitle: subtitle == null ? null : Text(subtitle!),
          trailing: const Icon(Icons.chevron_right),
          onTap: onTap,
        ),
      ),
    );
  }
}
