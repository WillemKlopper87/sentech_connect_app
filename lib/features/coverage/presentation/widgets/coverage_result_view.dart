import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';
import 'package:sentech_connect_app/features/coverage/presentation/coverage_text.dart';
import 'package:sentech_connect_app/features/coverage/presentation/widgets/coverage_option_card.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// The platform's answer, as the server decided it: one card per option (the
/// server's primary first, the rest in its order), the notices its disclaimer
/// keys name, and a footer that says which data the answer came from and that
/// these are predictions. Nothing here computes a band, a speed or a verdict.
class CoverageResultView extends StatelessWidget {
  const CoverageResultView({super.key, required this.check, this.meta, this.onNotify, this.onRetry});

  final CoverageCheck check;
  final CoverageMeta? meta;

  /// Opens the waiting-list form for a technology (null when the provider cannot take sign-ups).
  final void Function(TechnologyInterest interest)? onNotify;

  /// Asks again; offered for an answer the app cannot read.
  final VoidCallback? onRetry;

  static TechnologyInterest _interest(CoverageTechnology technology) => switch (technology) {
    CoverageTechnology.fiveG => TechnologyInterest.fiveG,
    CoverageTechnology.lte => TechnologyInterest.lte,
    CoverageTechnology.unknown => TechnologyInterest.any,
  };

  /// The primary option first, then the others in the server's order.
  List<CoverageOption> get _ordered {
    final primary = check.primaryIndex;
    if (primary == null || check.options.isEmpty) return check.options;
    return [check.options[primary], for (var i = 0; i < check.options.length; i++) if (i != primary) check.options[i]];
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final options = _ordered;
    final children = <Widget>[];

    void gap([double h = 12]) => children.add(SizedBox(height: h));

    if (options.isNotEmpty) {
      children.add(
        Semantics(
          header: true,
          child: Text(
            check.hasCoveredOption
                ? l10n.coverageOptionsTitle
                : (options.any((o) => o.kind == OptionKind.planned) ? l10n.coverageStatusPlanned : l10n.coverageOptionsTitleNeutral),
            style: theme.textTheme.titleMedium,
          ),
        ),
      );
      gap();
      for (final option in options) {
        children.add(
          CoverageOptionCard(
            option: option,
            onNotify: onNotify == null ? null : () => onNotify!(_interest(option.technology)),
          ),
        );
        gap();
      }
    } else {
      switch (check.status) {
        case CoverageAnswer.covered:
          // An older server that names no options: coverage is predicted here, nothing more.
          children.addAll([
            Text(l10n.coverageOptionPredictedTitle, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(l10n.coverageOptionPredictedText),
          ]);
        case CoverageAnswer.planned:
          children.add(Text(l10n.coverageStatusPlanned, style: theme.textTheme.titleMedium));
        case CoverageAnswer.notCovered:
          children.add(Text(l10n.coverageNotCoveredTitle, style: theme.textTheme.titleMedium));
          final nearest = check.nearest == null ? null : nearestText(l10n, check.nearest!);
          if (nearest != null) children.addAll([const SizedBox(height: 8), Text(nearest)]);
        case CoverageAnswer.unknown:
          children.addAll([
            Text(l10n.coverageStatusUnreadable),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh, size: 18), label: Text(l10n.commonRetry)),
            ],
          ]);
      }
      // No option to carry the button: the answer-level flag decides.
      if (check.status != CoverageAnswer.unknown && check.waitlistAvailable && onNotify != null) {
        children.addAll([
          const SizedBox(height: 12),
          Text(l10n.coverageNotifyPrompt),
          const SizedBox(height: 8),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: OutlinedButton(onPressed: () => onNotify!(TechnologyInterest.any), child: Text(l10n.coverageNotifyMe)),
          ),
        ]);
      }
      gap();
    }

    // The notices: a covered answer always carries the estimate, indoor and cooling-off notices
    // (spec section 5); every other key the server named has its text, an unknown key the generic one.
    final keys = <String>[
      ...check.disclaimerKeys,
      if (check.hasCoveredOption || (options.isEmpty && check.status == CoverageAnswer.covered))
        for (final required in const ['coverage.estimate', 'coverage.indoor', 'commerce.cooling_off'])
          if (!check.disclaimerKeys.contains(required)) required,
    ];
    final notices = <String>[];
    var generic = false;
    for (final key in keys) {
      final text = disclaimerText(l10n, key);
      if (text == null) {
        generic = true;
      } else if (!notices.contains(text)) {
        notices.add(text);
      }
    }
    if (generic) notices.add(l10n.coverageDisclaimerGeneric);
    for (final notice in notices) {
      children.addAll([Text(notice, style: theme.textTheme.bodySmall), const SizedBox(height: 6)]);
    }

    children.add(_Footer(check: check, meta: meta));

    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Which data the answer came from (release label and date, or the dataset version), where it
/// comes from, who it is attributed to, what the figures measure and that these are predictions.
class _Footer extends StatelessWidget {
  const _Footer({required this.check, required this.meta});

  final CoverageCheck check;
  final CoverageMeta? meta;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final primary = check.primary;
    final release = releaseText(
      context,
      label: primary?.releaseLabel,
      date: primary?.releaseDate,
      version: primary?.datasetVersion ?? check.datasetVersion,
    );
    final source = sourceText(l10n, primary?.sourceKey);
    final attribution = meta?.attribution;
    final style = theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final lines = <String>[
      if (release.isNotEmpty) release,
      ?source,
      if (attribution != null && attribution.isNotEmpty) attribution,
      l10n.coverageFooterPredicted,
    ];
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [for (final line in lines) Padding(padding: const EdgeInsets.only(bottom: 2), child: Text(line, style: style))],
      ),
    );
  }
}
