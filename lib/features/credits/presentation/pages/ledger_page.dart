import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/ledger_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/credits_text.dart';
import 'package:sentech_connect_app/features/credits/presentation/widgets/credits_notice.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// The history of credits earned and used, newest first, a page at a time.
/// Needs a [LedgerCubit] above it.
class CreditsLedgerPage extends StatelessWidget {
  const CreditsLedgerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsLedgerTitle)),
      body: SafeArea(
        child: BlocBuilder<LedgerCubit, LedgerState>(
          builder: (context, state) => switch (state.status) {
            LedgerStatus.loading => const Center(child: CircularProgressIndicator()),
            LedgerStatus.unavailable => CreditsMessage(l10n.creditsUnavailable),
            LedgerStatus.error => FailureView(failure: state.failure, onRetry: () => context.read<LedgerCubit>().refresh()),
            LedgerStatus.ready =>
              state.items.isEmpty
                  ? CreditsMessage(l10n.creditsLedgerEmpty)
                  : RefreshIndicator(
                      onRefresh: () => context.read<LedgerCubit>().refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          for (final entry in state.items) _EntryTile(entry: entry),
                          if (state.moreFailure != null)
                            FailureView(
                              failure: state.moreFailure,
                              compact: true,
                              onRetry: () => context.read<LedgerCubit>().loadMore(),
                            )
                          else if (state.loadingMore)
                            const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator()))
                          else if (state.hasMore)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: OutlinedButton(
                                key: const Key('credits-ledger-more'),
                                onPressed: () => context.read<LedgerCubit>().loadMore(),
                                child: Text(l10n.creditsLedgerMore),
                              ),
                            ),
                        ],
                      ),
                    ),
          },
        ),
      ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry});

  final CreditEntry entry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final positive = entry.credits > 0;
    final amount = '${positive ? '+' : ''}${entry.credits}';
    final when = DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(entry.createdAt.toLocal());
    return ListTile(
      key: Key('credits-entry-${entry.id}'),
      contentPadding: EdgeInsets.zero,
      title: Text(entryTitle(l10n, entry)),
      subtitle: Text('${entryKindText(l10n, entry.kind)} · $when'),
      trailing: Semantics(
        label: l10n.creditsAmount(entry.credits.abs()),
        child: ExcludeSemantics(
          child: Text(
            amount,
            style: theme.textTheme.titleMedium?.copyWith(
              color: positive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
