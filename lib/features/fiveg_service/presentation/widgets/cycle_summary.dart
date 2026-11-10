import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/time/sast.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// When the month's allowance resets, how many days that is, and any data
/// carried over from last month. [today] is the current instant; the day is
/// taken in South Africa time.
class CycleSummary extends StatelessWidget {
  const CycleSummary({
    super.key,
    required this.cycleEnd,
    required this.today,
    this.rolloverMb,
  });

  final DateTime cycleEnd;
  final DateTime today;
  final int? rolloverMb;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final days = daysUntilReset(cycleEnd, sastDay(today));
    final rollover = rolloverMb;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.fivegResetsOn(formatApiDay(context, resetDayFor(cycleEnd))),
          style: theme.textTheme.bodyLarge,
        ),
        const SizedBox(height: 2),
        Text(days == 1 ? l10n.fivegDaysLeftOne : l10n.fivegDaysLeftMany(days), style: muted),
        if (rollover != null && rollover > 0) ...[
          const SizedBox(height: 8),
          Text(l10n.fivegRollover(formatDataSize(rollover)), style: muted),
        ],
      ],
    );
  }
}
