import 'package:flutter/material.dart';
import 'package:sentech_connect_app/core/money/money.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/service_format.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// 214748364800 bytes -> "200". Binary gigabytes, as the platform's quotas are.
String formatFupGigabytes(int bytes) {
  final gb = bytes / (1024 * 1024 * 1024);
  return gb == gb.roundToDouble() ? gb.toStringAsFixed(0) : gb.toStringAsFixed(1);
}

/// The monthly price line. The API does not say whether prices include VAT
/// (plan doc Q9), so no VAT wording is added: VAT shows on the invoice.
String planPriceLine(BuildContext context, SubscriberPlan plan) =>
    context.l10n.servicePricePerMonth(formatRands(plan.priceCents));

String planSpeedLine(BuildContext context, SubscriberPlan plan) =>
    context.l10n.serviceSpeeds(formatMbps(plan.downKbps), formatMbps(plan.upKbps));

/// Fair-use lines (data amount, then what happens after it); empty when the
/// plan has no fair-use limit.
List<String> planFairUseLines(BuildContext context, SubscriberPlan plan) {
  final bytes = plan.fupBytes;
  if (bytes == null) return const [];
  final l10n = context.l10n;
  final lines = [l10n.planFairUse(l10n.planGigabytes(formatFupGigabytes(bytes)))];
  final down = plan.fupDownKbps;
  final up = plan.fupUpKbps;
  if (plan.fupAction != 'none') {
    lines.add(
      down != null && up != null
          ? l10n.planFairUseThrottle(formatMbps(down), formatMbps(up))
          : l10n.planFairUseReduced,
    );
  }
  return lines;
}

String? planBurstLine(BuildContext context, SubscriberPlan plan) {
  final down = plan.burstDownKbps;
  final up = plan.burstUpKbps;
  final seconds = plan.burstSeconds;
  if (down == null || up == null || seconds == null) return null;
  return context.l10n.planBurst(formatMbps(down), formatMbps(up), seconds);
}

/// "ID check needed" chip.
class PlanIdCheckChip extends StatelessWidget {
  const PlanIdCheckChip({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.secondaryContainer, borderRadius: BorderRadius.circular(999)),
      child: Text(
        context.l10n.planIdCheckChip,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: scheme.onSecondaryContainer),
      ),
    );
  }
}

/// Kind chip (home hotspot / fixed wireless).
class PlanKindChip extends StatelessWidget {
  const PlanKindChip(this.kind, {super.key});

  final SubscriberPlanKind kind;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(999)),
      child: Text(serviceKindLabel(context, kind), style: Theme.of(context).textTheme.labelMedium),
    );
  }
}
