import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/credits_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/streak_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/credits_text.dart';
import 'package:sentech_connect_app/features/credits/presentation/widgets/credits_notice.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The daily check-in. Needs a [StreakCubit] and a [CreditsCubit] above it (the
/// wallet tells whether it is frozen). What counts as a day is the server's:
/// the page shows the server's own date and says the day follows South African
/// time; the phone's clock and time zone play no part. A second check-in the
/// same day is "already checked in", not an error. After a check-in the wallet
/// is read again.
class StreakPage extends StatelessWidget {
  const StreakPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsStreakTitle)),
      body: SafeArea(
        child: BlocListener<StreakCubit, StreakCubitState>(
          listenWhen: (previous, current) =>
              previous.claimStatus != ClaimStatus.done && current.claimStatus == ClaimStatus.done,
          listener: (context, state) => context.read<CreditsCubit>().refresh(),
          child: BlocBuilder<StreakCubit, StreakCubitState>(
            builder: (context, state) => switch (state.status) {
              StreakStatus.loading => const Center(child: CircularProgressIndicator()),
              StreakStatus.unavailable => CreditsMessage(l10n.creditsUnavailable),
              StreakStatus.error => FailureView(
                failure: state.failure,
                onRetry: () => context.read<StreakCubit>().refresh(),
              ),
              StreakStatus.ready => RefreshIndicator(
                onRefresh: () => context.read<StreakCubit>().refresh(),
                child: _Loaded(state: state),
              ),
            },
          ),
        ),
      ),
    );
  }
}

class _Loaded extends StatelessWidget {
  const _Loaded({required this.state});

  final StreakCubitState state;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final streak = state.streak!;
    final rules = streak.rules;
    final frozen = context.watch<CreditsCubit>().state.summary?.frozen ?? false;
    final claiming = state.claimStatus == ClaimStatus.claiming;
    final claimNotice = blockingNoticeText(l10n, state.claimFailure);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final date = DateFormat.yMMMMd(locale).format(parseApiDate(streak.day));
    final canClaim = !frozen && !state.claimBlocked && !claiming && !streak.claimedToday;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(20),
      children: [
        if (frozen) ...[CreditsNotice(text: l10n.creditsFrozenNotice, warning: true), const SizedBox(height: 12)],
        if (claimNotice != null && !frozen) ...[CreditsNotice(text: claimNotice, warning: true), const SizedBox(height: 12)],
        Text(l10n.creditsStreakDayLine(date), key: const Key('credits-streak-dayline')),
        const SizedBox(height: 16),
        _Stat(label: l10n.creditsStreakRun, value: l10n.creditsDaysCount(streak.runDays), big: true),
        _Stat(label: l10n.creditsStreakBest, value: l10n.creditsDaysCount(streak.bestRunDays)),
        _Stat(label: l10n.creditsStreakTotal, value: l10n.creditsDaysCount(streak.totalDays)),
        _Stat(label: l10n.creditsStreakFreezes, value: '${streak.freezes}', hint: l10n.creditsStreakFreezesHint),
        const SizedBox(height: 8),
        Text(l10n.creditsStreakNext(l10n.creditsDaysCount(streak.nextMilestoneInDays)), style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (state.claim case final claim?) ...[_ClaimResultCard(claim: claim), const SizedBox(height: 12)],
        if (state.claimStatus == ClaimStatus.failed && claimNotice == null && state.claimFailure != null) ...[
          FailureView(
            failure: state.claimFailure,
            compact: true,
            onRetry: () => context.read<StreakCubit>().claim(),
          ),
          const SizedBox(height: 12),
        ],
        if (streak.claimedToday && state.claim == null) ...[
          Text(l10n.creditsAlreadyCheckedIn, key: const Key('credits-already'), style: theme.textTheme.bodyLarge),
          const SizedBox(height: 12),
        ],
        FilledButton(
          key: const Key('credits-checkin-button'),
          onPressed: canClaim ? () => context.read<StreakCubit>().claim() : null,
          child: Text(claiming ? l10n.creditsCheckingIn : l10n.creditsCheckInButton),
        ),
        const SizedBox(height: 20),
        Text(l10n.creditsStreakRuleDaily(l10n.creditsAmount(rules.dailyCredits)), style: theme.textTheme.bodySmall),
        Text(
          l10n.creditsStreakRuleBonus(
            l10n.creditsAmount(rules.shortMilestoneBonus),
            l10n.creditsDaysCount(rules.shortMilestoneDays),
          ),
          style: theme.textTheme.bodySmall,
        ),
        Text(
          l10n.creditsStreakRuleBonus(
            l10n.creditsAmount(rules.longMilestoneBonus),
            l10n.creditsDaysCount(rules.longMilestoneDays),
          ),
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.hint, this.big = false});

  final String label;
  final String value;
  final String? hint;
  final bool big;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(child: Text(label)),
              Text(value, style: big ? theme.textTheme.headlineSmall : theme.textTheme.titleMedium),
            ],
          ),
          if (hint != null) Text(hint!, style: theme.textTheme.bodySmall),
        ],
      ),
    );
  }
}

class _ClaimResultCard extends StatelessWidget {
  const _ClaimResultCard({required this.claim});

  final ClaimResult claim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final paid = claim.credits + claim.bonusCredits;
    final cappedBy = claim.cappedBy;
    final lines = <String>[];
    if (!claim.claimed) {
      lines.add(l10n.creditsAlreadyCheckedIn);
    } else if (cappedBy != null && paid == 0) {
      lines.add(cappedSentence(l10n, cappedBy));
    } else {
      lines.add(l10n.creditsCheckInEarned(l10n.creditsAmount(claim.credits)));
      if (claim.bonusCredits > 0) lines.add(l10n.creditsCheckInBonus(l10n.creditsAmount(claim.bonusCredits)));
      if (claim.freezesUsed > 0) lines.add(l10n.creditsCheckInFreezeUsed(claim.freezesUsed));
      if (cappedBy != null) lines.add(l10n.creditsCheckInPartlyCapped);
    }
    return CreditsNotice(
      key: const Key('credits-claim-result'),
      text: lines.join('\n'),
      icon: Icons.check_circle_outline,
    );
  }
}
