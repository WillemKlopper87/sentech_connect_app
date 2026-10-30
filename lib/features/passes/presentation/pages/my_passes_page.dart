import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/hotspot_login/presentation/widgets/get_online_entry.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/bloc/passes_cubit.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_format.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_summary.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

class MyPassesPage extends StatefulWidget {
  const MyPassesPage({super.key, this.onBuyPass, this.now = DateTime.now});

  /// Empty state shortcut to the Shop's hotspot passes.
  final VoidCallback? onBuyPass;
  final DateTime Function() now;

  @override
  State<MyPassesPage> createState() => _MyPassesPageState();
}

class _MyPassesPageState extends State<MyPassesPage> {
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
          final now = widget.now();
          return RefreshIndicator(
            onRefresh: cubit.load,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
              children: [
                if (state.loadedAt case final loadedAt?)
                  if (state.fromCache ||
                      now.difference(loadedAt) > const Duration(minutes: 5))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        l10n.passesUpdated(
                          formatTimeLeft(l10n, now.difference(loadedAt)),
                        ),
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(l10n.passesShowExpired),
                  value: state.includeExpired,
                  onChanged: cubit.setIncludeExpired,
                ),
                GetOnlineEntry(passes: state.passes, now: now),
                if (state.passes.isEmpty) ...[
                  const SizedBox(height: 24),
                  Text(l10n.passesEmpty, textAlign: TextAlign.center),
                  const SizedBox(height: 8),
                  Text(
                    l10n.passesJustPaidHint,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  if (widget.onBuyPass case final buy?) ...[
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: buy,
                      child: Text(l10n.dashboardBuyPass),
                    ),
                  ],
                ] else
                  for (final pass in state.passes) ...[
                    _PassCard(pass: pass, now: now),
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
  const _PassCard({required this.pass, required this.now});

  final Pass pass;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final l10n = context.l10n;
    final summary = PassSummary.of(
      pass,
      l10n,
      now: now,
      localeTag: Localizations.localeOf(context).toLanguageTag(),
    );
    final status = switch (summary.effectiveStatus) {
      PassStatus.active => l10n.passesStatusActive,
      PassStatus.scheduled => l10n.passesStatusScheduled,
      PassStatus.suspended => l10n.passesStatusSuspended,
      PassStatus.expired => l10n.passesStatusExpired,
      PassStatus.exhausted => l10n.passesStatusExhausted,
      PassStatus.revoked => l10n.passesStatusRevoked,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(pass.productName, style: theme.textTheme.titleMedium),
                Chip(label: Text(status), visualDensity: VisualDensity.compact),
              ],
            ),
            const SizedBox(height: 4),
            Text(summary.headline, style: theme.textTheme.titleMedium),
            if (summary.capText case final cap?)
              Text(cap, style: theme.textTheme.bodyMedium),
            Text(summary.endsText, style: theme.textTheme.bodyMedium),
            Text(
              l10n.passesDevices(pass.maxDevices),
              style: theme.textTheme.bodyMedium,
            ),
            if (summary.fractionLeft != null && pass.isCurrent) ...[
              const SizedBox(height: 10),
              LinearProgressIndicator(value: summary.fractionLeft),
            ],
          ],
        ),
      ),
    );
  }
}
