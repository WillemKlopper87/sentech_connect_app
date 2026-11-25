import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/presentation/bloc/missions_cubit.dart';
import 'package:sentech_connect_app/features/credits/presentation/credits_text.dart';
import 'package:sentech_connect_app/features/credits/presentation/widgets/credits_notice.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';
import 'package:sentech_connect_app/shared/widgets/failure_view.dart';

/// Missions as the server evaluated them. The page only draws the server's
/// `progress`, `target` and `status`; it never counts anything itself. Needs a
/// [MissionsCubit] above it.
class MissionsPage extends StatelessWidget {
  const MissionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.creditsMissionsTitle)),
      body: SafeArea(
        child: BlocBuilder<MissionsCubit, MissionsState>(
          builder: (context, state) => switch (state.status) {
            ListStatus.loading => const Center(child: CircularProgressIndicator()),
            ListStatus.unavailable => CreditsMessage(l10n.creditsUnavailable),
            ListStatus.error => FailureView(failure: state.failure, onRetry: () => context.read<MissionsCubit>().refresh()),
            ListStatus.ready =>
              state.missions.isEmpty
                  ? CreditsMessage(l10n.creditsMissionsEmpty)
                  : RefreshIndicator(
                      onRefresh: () => context.read<MissionsCubit>().refresh(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.all(20),
                        children: [for (final mission in state.missions) _MissionCard(mission: mission)],
                      ),
                    ),
          },
        ),
      ),
    );
  }
}

class _MissionCard extends StatelessWidget {
  const _MissionCard({required this.mission});

  final Mission mission;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    // Only drawing: the fraction is the server's progress over the server's target.
    final fraction = mission.target <= 0 ? 0.0 : (mission.progress / mission.target).clamp(0.0, 1.0);
    final status = switch (mission.status) {
      MissionStatus.completed => l10n.creditsMissionDone,
      MissionStatus.ready => l10n.creditsMissionReady,
      MissionStatus.inProgress => l10n.creditsMissionProgress('${mission.progress}', '${mission.target}'),
    };
    return Card(
      key: Key('credits-mission-${mission.key}'),
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(child: Text(missionName(l10n, mission.key), style: theme.textTheme.titleMedium)),
                if (mission.status == MissionStatus.completed) const Icon(Icons.check_circle, size: 20),
              ],
            ),
            const SizedBox(height: 4),
            Text(l10n.creditsMissionReward(l10n.creditsAmount(mission.rewardCredits)), style: theme.textTheme.bodyMedium),
            const SizedBox(height: 10),
            LinearProgressIndicator(value: fraction, minHeight: 8),
            const SizedBox(height: 6),
            Text(status, key: Key('credits-mission-status-${mission.key}')),
            const SizedBox(height: 2),
            Text(
              missionWindowText(l10n, mission.window),
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
