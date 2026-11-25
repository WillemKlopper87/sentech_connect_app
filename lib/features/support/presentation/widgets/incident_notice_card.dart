import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/incidents_cubit.dart';
import 'package:sentech_connect_app/features/support/presentation/tickets_text.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// Known network incidents on the Help tab. Needs an [IncidentsCubit] above it.
/// Shows ONLY what the provider wrote (title, body, latest update) and when it
/// started: the app adds no cause and no time to fix. With no open incident, or
/// when the load failed, it shows nothing at all (never an error).
class IncidentNoticeCard extends StatelessWidget {
  const IncidentNoticeCard({super.key});

  /// At most this many incidents are listed; the newest come first.
  static const maxShown = 3;

  @override
  Widget build(BuildContext context) => BlocBuilder<IncidentsCubit, IncidentsState>(
    builder: (context, state) {
      if (state.open.isEmpty) return const SizedBox.shrink();
      final l10n = context.l10n;
      final theme = Theme.of(context);
      final tag = Localizations.localeOf(context).toLanguageTag();
      return Card(
        key: const Key('incident-notice-card'),
        margin: const EdgeInsets.only(bottom: 16),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Semantics(
            container: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 20, color: theme.colorScheme.onSurface),
                    const SizedBox(width: 8),
                    Expanded(child: Text(l10n.ticketsIncidentTitle, style: theme.textTheme.titleSmall)),
                  ],
                ),
                for (final incident in state.open.take(maxShown)) ...[
                  const SizedBox(height: 12),
                  Text(incident.title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(
                    '${incidentSeverityLabel(l10n, incident.severity)} · ${l10n.ticketsIncidentSince(ticketDateTime(tag, incident.startedAt))}',
                    style: theme.textTheme.bodySmall,
                  ),
                  if (incident.body.isNotEmpty) ...[const SizedBox(height: 4), Text(incident.body, style: theme.textTheme.bodyMedium)],
                  if (_latestUpdateText(incident) case final update?) ...[
                    const SizedBox(height: 4),
                    Text(l10n.ticketsIncidentLatestUpdate, style: theme.textTheme.labelMedium),
                    Text(update, style: theme.textTheme.bodyMedium),
                  ],
                ],
              ],
            ),
          ),
        ),
      );
    },
  );

  /// The latest update's text when it says something the incident body does not.
  static String? _latestUpdateText(Incident incident) {
    if (incident.updates.isEmpty) return null;
    final text = incident.updates.last.body;
    return text.isEmpty || text == incident.body ? null : text;
  }
}
