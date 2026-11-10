import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// How a notice is coloured. The icon and the words carry the meaning too.
enum UsageNoticeTone { info, warning, critical, calm }

/// One plain-language notice: an icon, the text, and an optional line under it.
class UsageNotice extends StatelessWidget {
  const UsageNotice({
    super.key,
    required this.icon,
    required this.text,
    this.detail,
    this.tone = UsageNoticeTone.info,
  });

  final IconData icon;
  final String text;
  final String? detail;
  final UsageNoticeTone tone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Neutral surface for every tone: the icon colour and the border carry the
    // tone, and the words carry the meaning (so no pairing relies on colour alone).
    final accent = switch (tone) {
      UsageNoticeTone.info || UsageNoticeTone.calm => scheme.primary,
      UsageNoticeTone.warning => scheme.onSurface,
      UsageNoticeTone.critical => scheme.error,
    };
    final foreground = scheme.onSurface;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accent, width: 1.5),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(text, style: theme.textTheme.bodyLarge?.copyWith(color: foreground)),
                if (detail != null) ...[
                  const SizedBox(height: 4),
                  Text(detail!, style: theme.textTheme.bodyMedium?.copyWith(color: foreground)),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The headline for the service's current state (see [headlineFor]).
class UsageHeadlineBanner extends StatelessWidget {
  const UsageHeadlineBanner({super.key, required this.headline, this.restoringTimedOut = false});

  final UsageHeadline headline;

  /// The restore polling stopped: ask for a manual refresh.
  final bool restoringTimedOut;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return switch (headline) {
      UsageHeadline.normal => UsageNotice(
        icon: Icons.check_circle_outline,
        text: l10n.fivegStateNormal,
      ),
      UsageHeadline.slowLane => UsageNotice(
        icon: Icons.speed,
        tone: UsageNoticeTone.warning,
        text: l10n.fivegStateSlowLane,
      ),
      UsageHeadline.cutOff => UsageNotice(
        icon: Icons.block,
        tone: UsageNoticeTone.critical,
        text: l10n.fivegStateCutOff,
      ),
      UsageHeadline.outOfBundle => UsageNotice(
        icon: Icons.warning_amber_rounded,
        tone: UsageNoticeTone.critical,
        text: l10n.fivegStateOutOfBundle,
      ),
      UsageHeadline.fupThrottled => UsageNotice(
        icon: Icons.speed,
        tone: UsageNoticeTone.warning,
        text: l10n.fivegStateFup,
      ),
      UsageHeadline.restoring => UsageNotice(
        icon: Icons.sync,
        tone: UsageNoticeTone.calm,
        text: l10n.fivegStateRestoring,
        detail: restoringTimedOut ? l10n.fivegRestoringTimedOut : l10n.fivegRestoringHint,
      ),
    };
  }
}

/// The threshold notice at 50, 80 or 100 percent. [UsageWarning.none] shows nothing.
class UsageWarningBanner extends StatelessWidget {
  const UsageWarningBanner({super.key, required this.warning});

  final UsageWarning warning;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final text = switch (warning) {
      UsageWarning.none => null,
      UsageWarning.p50 => l10n.fivegWarn50,
      UsageWarning.p80 => l10n.fivegWarn80,
      UsageWarning.p100 => l10n.fivegWarn100,
    };
    if (text == null) return const SizedBox.shrink();
    return UsageNotice(
      icon: warning == UsageWarning.p100 ? Icons.error_outline : Icons.info_outline,
      tone: warning == UsageWarning.p100 ? UsageNoticeTone.critical : UsageNoticeTone.warning,
      text: text,
    );
  }
}
