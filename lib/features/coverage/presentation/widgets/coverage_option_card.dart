import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/presentation/coverage_text.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// One technology's answer at the place, exactly as the server gave it.
///
/// A speed range appears only for a covered option that carries a band AND a
/// range (the server withholds both for a placeholder ladder, a non-download
/// basis or an unaudited dataset); then the card says what the figures measure
/// and that they are predicted. With no band the card says coverage is predicted
/// and shows no figure, in words. Colour is never the only signal: every state
/// has an icon and a heading in words.
class CoverageOptionCard extends StatelessWidget {
  const CoverageOptionCard({super.key, required this.option, this.onNotify});

  final CoverageOption option;

  /// Offered only when the server says [CoverageOption.notifyAvailable] and the provider can take sign-ups.
  final VoidCallback? onNotify;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final name = technologyName(l10n, option.technology, option.technologyRaw);
    final planned = option.kind == OptionKind.planned;
    final unknown = option.kind == OptionKind.unknown;
    // A kind the app does not know is a neutral card: the technology and nothing that claims coverage.
    final heading = unknown ? name : (planned ? l10n.coverageOptionPlannedHeading(name) : l10n.coverageOptionCoveredHeading(name));
    final band = option.band;
    final title = band == null ? null : bandTitle(l10n, band.key);
    final text = band == null ? null : bandText(l10n, band.key);
    final confidence = confidenceText(l10n, option.confidence);
    final showFigures = option.kind == OptionKind.covered && band != null && option.hasFigures;
    // What the figures measure is said where a figure is shown, and nowhere else.
    final showMeasure = showFigures;
    final border = theme.colorScheme.outlineVariant;
    final canNotify = onNotify != null && option.notifyAvailable;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: border),
        color: theme.colorScheme.surface,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MergeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      planned ? Icons.schedule : Icons.check_circle_outline,
                      color: theme.colorScheme.primary,
                      semanticLabel: null,
                    ),
                    const SizedBox(width: 10),
                    Expanded(child: Text(heading, style: theme.textTheme.titleMedium)),
                  ],
                ),
                const SizedBox(height: 8),
                if (unknown)
                  Text(l10n.coverageOptionUnknownText)
                else if (planned)
                  Text(
                    option.expectedDate == null
                        ? l10n.coverageOptionPlannedNoDate
                        : l10n.coverageOptionPlannedText(plannedMonth(context, option.expectedDate!)),
                  )
                else ...[
                  // Words first: the band is named, or the plain "predicted here" with no speed.
                  Text(title ?? l10n.coverageOptionPredictedTitle, style: theme.textTheme.titleSmall),
                  const SizedBox(height: 4),
                  Text(text ?? l10n.coverageOptionPredictedText),
                  if (showFigures && option.typicalDown != null) ...[
                    const SizedBox(height: 8),
                    Text(l10n.coverageSpeedTypical(option.typicalDown!.minMbps.toString(), option.typicalDown!.maxMbps.toString())),
                  ],
                  if (showFigures && option.busyHourDown != null) ...[
                    const SizedBox(height: 4),
                    Text(l10n.coverageSpeedBusy(option.busyHourDown!.minMbps.toString(), option.busyHourDown!.maxMbps.toString())),
                  ],
                ],
                if (showMeasure) ...[
                  const SizedBox(height: 8),
                  Text(measureText(l10n, option), style: theme.textTheme.bodySmall),
                ],
                if (option.kind == OptionKind.covered && confidence != null) ...[
                  const SizedBox(height: 4),
                  Text(confidence, style: theme.textTheme.bodySmall),
                ],
                if (option.nearBoundary) ...[
                  const SizedBox(height: 8),
                  Text(l10n.coverageOptionNearBoundary, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          if (canNotify) ...[
            const SizedBox(height: 12),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: OutlinedButton(onPressed: onNotify, child: Text(l10n.coverageNotifyMe)),
            ),
          ],
        ],
      ),
    );
  }
}
