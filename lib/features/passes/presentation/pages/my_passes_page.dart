import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

class MyPassesPage extends StatelessWidget {
  const MyPassesPage({super.key});

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
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.passesShowExpired),
                  value: state.includeExpired,
                  onChanged: cubit.setIncludeExpired,
                ),
                if (state.passes.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 24),
                    child: Text(l10n.passesEmpty, textAlign: TextAlign.center),
                  )
                else
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
            Text(
              pass.status == PassStatus.scheduled
                  ? l10n.passesStarts(format.format(pass.startsAt.toLocal()))
                  : l10n.passesExpires(format.format(pass.expiresAt.toLocal())),
              style: theme.textTheme.bodyMedium,
            ),
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
