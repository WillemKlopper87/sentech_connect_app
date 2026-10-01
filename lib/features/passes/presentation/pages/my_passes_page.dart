import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_format.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

class MyPassesPage extends StatelessWidget {
  const MyPassesPage({super.key, this.onBuyPass});

  /// Empty state shortcut to the Shop's hotspot passes.
  final VoidCallback? onBuyPass;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.passesTitle)),
      body: BlocBuilder<PassesCubit, PassesState>(
        builder: (context, state) {
          final cubit = context.read<PassesCubit>();
          if (state.status == PassesStatus.loading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (state.status == PassesStatus.failure) {
            return FailureView(failure: state.failure, onRetry: cubit.load);
          }
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.passesShowExpired),
                  value: state.includeExpired,
                  onChanged: cubit.setIncludeExpired,
                ),
                if (state.passes.isEmpty) ...[
                  const SizedBox(height: 24),
                  Text(l10n.passesEmpty, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    l10n.passesJustPaidHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (onBuyPass case final buy?) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: buy,
                      child: Text(l10n.dashboardBuyPass),
                    ),
                  ],
                ] else
                  for (final pass in state.passes) ...[
                    _PassCard(pass: pass),
                    const SizedBox(height: 12),
                  ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _PassCard extends StatelessWidget {
  const _PassCard({required this.pass});

  final Pass pass;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final format = DateFormat.MMMd(
      Localizations.localeOf(context).toLanguageTag(),
    ).add_Hm();
    final status = switch (pass.status) {
      PassStatus.active => l10n.passesStatusActive,
      PassStatus.scheduled => l10n.passesStatusScheduled,
      PassStatus.expired => l10n.passesStatusExpired,
      PassStatus.exhausted => l10n.passesStatusExhausted,
      PassStatus.revoked => l10n.passesStatusRevoked,
    };
    final fraction = pass.dataUsedFraction;
    final dataLeft = dataLeftText(l10n, pass);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    pass.productName,
                    style: theme.textTheme.titleMedium,
                  ),
                ),
                Chip(label: Text(status), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 4),
            Text(switch (pass.status) {
              PassStatus.scheduled => l10n.passesStarts(
                format.format(pass.startsAt.toLocal()),
              ),
              PassStatus.active => l10n.passesExpires(
                format.format(pass.expiresAt.toLocal()),
              ),
              PassStatus.expired => l10n.passesExpiredAt(
                format.format(pass.expiresAt.toLocal()),
              ),
              PassStatus.exhausted || PassStatus.revoked => l10n.passesEndedAt(
                format.format(pass.expiresAt.toLocal()),
              ),
            }, style: theme.textTheme.bodyMedium),
            if (dataLeft != null && pass.isCurrent)
              Text(dataLeft, style: theme.textTheme.bodyMedium),
            Text(
              l10n.passesDevices(pass.maxDevices),
              style: theme.textTheme.bodyMedium,
            ),
            if (fraction != null && pass.isCurrent) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: fraction),
            ],
          ],
        ),
      ),
    );
  }
}
