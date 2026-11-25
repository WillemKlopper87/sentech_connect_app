import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/missions_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/credits_text.dart';
import 'package:sentech_connect_app/features/credits/presentation/widgets/credits_notice.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Badges as the server awarded them (earned, with the date, or the server's
/// progress towards them). Needs a [BadgesCubit] above it.
class BadgesPage extends StatelessWidget {
  const BadgesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsBadgesTitle)),
      body: SafeArea(
        child: BlocBuilder<BadgesCubit, BadgesState>(
          builder: (context, state) => switch (state.status) {
            ListStatus.loading => const Center(child: CircularProgressIndicator()),
            ListStatus.unavailable => CreditsMessage(l10n.creditsUnavailable),
            ListStatus.error => FailureView(failure: state.failure, onRetry: () => context.read<BadgesCubit>().refresh()),
            ListStatus.ready =>
              state.badges.isEmpty
                  ? CreditsMessage(l10n.creditsBadgesEmpty)
                  : RefreshIndicator(
                      onRefresh: () => context.read<BadgesCubit>().refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [for (final badge in state.badges) _BadgeTile(badge: badge)],
                      ),
                    ),
          },
        ),
      ),
    );
  }
}

class _BadgeTile extends StatelessWidget {
  const _BadgeTile({required this.badge});

  final CreditBadge badge;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final awarded = badge.awardedAt;
    final subtitle = badge.earned
        ? (awarded == null
              ? l10n.creditsBadgeEarnedNoDate
              : l10n.creditsBadgeEarned(
                  DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(awarded.toLocal()),
                ))
        : l10n.creditsBadgeLocked('${badge.progress}', '${badge.target}');
    return Card(
      key: Key('credits-badge-${badge.key}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        minTileHeight: 56,
        leading: Icon(
          badge.earned ? Icons.military_tech : Icons.military_tech_outlined,
          color: badge.earned ? scheme.primary : scheme.onSurfaceVariant,
        ),
        title: Text(badgeName(l10n, badge.key)),
        subtitle: Text(subtitle),
      ),
    );
  }
}
