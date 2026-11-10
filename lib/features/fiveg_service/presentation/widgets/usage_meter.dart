import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The month's data bar: a filled track up to the used share, with a mark at
/// 50, 80 and 100 percent. Meaning is never carried by colour alone: the
/// percentage and the used and allowance sizes are written out as text, and the
/// screen reader gets one sentence for the whole meter.
class UsageMeter extends StatelessWidget {
  const UsageMeter({super.key, required this.usedMb, required this.capMb, required this.usedPercent});

  final int usedMb;
  final int capMb;

  /// 0 to 100 (the platform's `used_percent`).
  final int usedPercent;

  /// The percentage the bar fills to: never past the full track.
  static double fillFraction(int percent) => (percent.clamp(0, 100)) / 100;

  static const _markPercents = [50, 80, 100];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final used = formatDataSize(usedMb);
    final cap = formatDataSize(capMb);
    final caption = l10n.fivegMeterUsed(used, cap);
    return Semantics(
      container: true,
      label: l10n.fivegMeterSemantics('$usedPercent', used, cap),
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            '${l10n.fivegPercentLabel('$usedPercent')} · $caption',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final filled = width * fillFraction(usedPercent);
              return SizedBox(
                height: 16,
                child: Stack(
                  children: [
                    Positioned.fill(
                      top: 2,
                      bottom: 2,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(color: scheme.outlineVariant),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      top: 2,
                      bottom: 2,
                      width: filled,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: scheme.primary,
                          borderRadius: BorderRadius.circular(6),
                        ),
                      ),
                    ),
                    for (final mark in _markPercents)
                      Positioned(
                        left: width * mark / 100 - 1,
                        top: 0,
                        bottom: 0,
                        width: 2,
                        child: ColoredBox(color: scheme.onSurface),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
