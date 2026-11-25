import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/credits_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/redeem_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/credits_text.dart';
import 'package:sentech_connect_app/features/credits/presentation/widgets/credits_notice.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_format.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Turns credits into a hotspot data pass. Needs a [CreditsCubit] (the wallet
/// and the provider's rates) and a [RedeemCubit] above it. Only the pack sizes
/// the server lists are offered; the data per pack is `credits x mb_per_credit`
/// from the same answer. A frozen or paused wallet is explained and every pack
/// is disabled. After a success the wallet is read again and the new pass is a
/// tap away in My passes ([onOpenPasses]).
class RedeemPage extends StatefulWidget {
  const RedeemPage({super.key, this.onOpenPasses});

  final VoidCallback? onOpenPasses;

  @override
  State<RedeemPage> createState() => _RedeemPageState();
}

class _RedeemPageState extends State<RedeemPage> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsRedeemTitle)),
      body: SafeArea(
        child: BlocListener<RedeemCubit, RedeemState>(
          listenWhen: (previous, current) =>
              previous.status != current.status &&
              (current.status == RedeemStatus.done ||
                  current.status == RedeemStatus.failed),
          // A result of any kind (and a failure above all: the answer may have been lost
          // after the credits were spent) means the wallet is read again.
          listener: (context, state) => context.read<CreditsCubit>().refresh(),
          child: BlocBuilder<CreditsCubit, CreditsState>(
            builder: (context, wallet) {
              final summary = wallet.summary;
              if (summary == null) {
                return switch (wallet.status) {
                  CreditsStatus.unavailable => CreditsMessage(
                    l10n.creditsUnavailable,
                  ),
                  CreditsStatus.error => FailureView(
                    failure: wallet.failure,
                    onRetry: () => context.read<CreditsCubit>().refresh(),
                  ),
                  _ => const Center(child: CircularProgressIndicator()),
                };
              }
              return BlocBuilder<RedeemCubit, RedeemState>(
                builder: (context, state) => state.status == RedeemStatus.done
                    ? _Done(
                        state: state,
                        summary: summary,
                        onOpenPasses: widget.onOpenPasses,
                        onAnother: _another,
                      )
                    : _Choose(
                        summary: summary,
                        state: state,
                        selected: _selected,
                        onSelect: (credits) =>
                            setState(() => _selected = credits),
                      ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _another() {
    context.read<RedeemCubit>().dismiss();
    setState(() => _selected = null);
  }
}

class _Choose extends StatelessWidget {
  const _Choose({
    required this.summary,
    required this.state,
    required this.selected,
    required this.onSelect,
  });

  final CreditsSummary summary;
  final RedeemState state;
  final int? selected;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final submitting = state.status == RedeemStatus.submitting;
    final blockedByWallet = summary.frozen;
    final blockedByRefusal = state.blocksActions;
    final blocked = blockedByWallet || blockedByRefusal;
    final notice = blockedByWallet
        ? l10n.creditsFrozenNotice
        : blockingNoticeText(l10n, state.failure);
    final pendingPack = state.pendingCredits;
    // While a redeem has an unknown outcome only that pack can be tried again.
    final choice = pendingPack ?? selected;
    final canRedeem =
        choice != null &&
        !blocked &&
        !submitting &&
        summary.rates.packSizes.contains(choice) &&
        choice <= summary.available;
    return RefreshIndicator(
      onRefresh: () => context.read<CreditsCubit>().refresh(),
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        children: [
          if (notice != null) ...[
            CreditsNotice(text: notice, warning: true),
            const SizedBox(height: 12),
          ],
          if (pendingPack != null && !blocked) ...[
            CreditsNotice(
              text: l10n.creditsRedeemPendingNotice,
              icon: Icons.sync_problem,
            ),
            const SizedBox(height: 12),
          ],
          Text(l10n.creditsHomeAvailable, style: theme.textTheme.labelLarge),
          Text(
            l10n.creditsAmount(summary.available),
            style: theme.textTheme.headlineSmall,
          ),
          const SizedBox(height: 12),
          Text(l10n.creditsRedeemIntro),
          const SizedBox(height: 12),
          if (summary.rates.packSizes.isEmpty)
            CreditsMessage(l10n.creditsRedeemNoPacks)
          else
            for (final size in summary.rates.packSizes)
              _PackTile(
                credits: size,
                data: formatMegabytes(l10n, summary.rates.megabytesFor(size)),
                selected: choice == size,
                enough: size <= summary.available,
                enabled:
                    !blocked &&
                    !submitting &&
                    (pendingPack == null || pendingPack == size),
                onTap: () => onSelect(size),
              ),
          const SizedBox(height: 8),
          if (state.status == RedeemStatus.failed &&
              !blockedByRefusal &&
              state.failure != null &&
              pendingPack == null)
            FailureView(
              failure: state.failure,
              compact: true,
              onRetry: () {
                final retry = state.credits ?? choice;
                if (retry != null) context.read<RedeemCubit>().redeem(retry);
              },
            ),
          const SizedBox(height: 8),
          FilledButton(
            key: const Key('credits-redeem-button'),
            onPressed: canRedeem
                ? () => context.read<RedeemCubit>().redeem(choice)
                : null,
            child: Text(
              submitting
                  ? l10n.creditsRedeeming
                  : choice == null
                  ? l10n.creditsTileRedeem
                  : pendingPack != null
                  ? l10n.creditsTryAgain
                  : l10n.creditsRedeemButton(l10n.creditsAmount(choice)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.creditsTermsLine(summary.rates.expiryDays.toString()),
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _PackTile extends StatelessWidget {
  const _PackTile({
    required this.credits,
    required this.data,
    required this.selected,
    required this.enough,
    required this.enabled,
    required this.onTap,
  });

  final int credits;
  final String data;
  final bool selected;
  final bool enough;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final scheme = Theme.of(context).colorScheme;
    final usable = enabled && enough;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(12),
        ),
        child: ListTile(
          key: Key('credits-pack-$credits'),
          minTileHeight: 56,
          enabled: usable,
          selected: selected,
          leading: Icon(
            selected
                ? Icons.radio_button_checked
                : Icons.radio_button_unchecked,
          ),
          title: Text(l10n.creditsAmount(credits)),
          subtitle: Text(
            enough ? l10n.creditsPackData(data) : l10n.creditsPackNotEnough,
          ),
          onTap: usable ? onTap : null,
        ),
      ),
    );
  }
}

class _Done extends StatelessWidget {
  const _Done({
    required this.state,
    required this.summary,
    required this.onOpenPasses,
    required this.onAnother,
  });

  final RedeemState state;
  final CreditsSummary summary;
  final VoidCallback? onOpenPasses;
  final VoidCallback onAnother;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final Pass? pass = state.pass;
    final credits = state.credits ?? 0;
    final megabytes = pass?.dataMb ?? summary.rates.megabytesFor(credits);
    final until = pass == null
        ? ''
        : DateFormat.yMMMd(
            Localizations.localeOf(context).toLanguageTag(),
          ).add_Hm().format(pass.expiresAt.toLocal());
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Icon(
          Icons.check_circle_outline,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        const SizedBox(height: 12),
        Text(
          l10n.creditsRedeemDoneTitle,
          style: theme.textTheme.titleLarge,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          l10n.creditsRedeemDoneBody(
            l10n.creditsAmount(credits),
            formatMegabytes(l10n, megabytes),
            until,
          ),
          key: const Key('credits-redeem-done'),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        if (onOpenPasses case final open?)
          FilledButton(
            key: const Key('credits-view-passes'),
            onPressed: open,
            child: Text(l10n.creditsViewPasses),
          ),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: onAnother, child: Text(l10n.commonDone)),
      ],
    );
  }
}
