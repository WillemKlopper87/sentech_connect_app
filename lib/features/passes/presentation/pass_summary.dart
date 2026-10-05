import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/features/passes/presentation/pass_format.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

enum UsageTier { plenty, low, critical, ended }

class PassSummary {
  const PassSummary({
    required this.headline,
    required this.capText,
    required this.fractionLeft,
    required this.endsText,
    required this.tier,
    required this.effectiveStatus,
  });
  final String headline;
  final String? capText;
  final double? fractionLeft;
  final String endsText;
  final UsageTier tier;
  final PassStatus effectiveStatus;

  static PassSummary of(
    Pass p,
    AppLocalizations l10n, {
    required DateTime now,
    required String localeTag,
  }) {
    final effectiveStatus =
        !p.expiresAt.isAfter(now) &&
            (p.status == PassStatus.active || p.status == PassStatus.scheduled)
        ? PassStatus.expired
        : p.status;
    final ended =
        effectiveStatus == PassStatus.expired ||
        effectiveStatus == PassStatus.exhausted ||
        effectiveStatus == PassStatus.revoked;
    final remaining = p.expiresAt.difference(now);
    final capped = p.dataMb != null;
    final cap = (p.dataMb ?? 0).clamp(0, 1 << 60);
    final left = (cap - p.usedBytes.clamp(0, 1 << 62) / (1024 * 1024)).clamp(
      0,
      cap,
    );
    final fraction = ended || !capped || cap == 0
        ? null
        : (left / cap).clamp(0, 1).toDouble();
    final tier = ended
        ? UsageTier.ended
        : effectiveStatus == PassStatus.scheduled
        ? UsageTier.plenty
        : fraction == null
        ? UsageTier.plenty
        : fraction <= .05
        ? UsageTier.critical
        : fraction <= .20
        ? UsageTier.low
        : UsageTier.plenty;
    final date = DateFormat.E(localeTag).add_Hm().format(p.expiresAt.toLocal());
    final ends = switch (effectiveStatus) {
      PassStatus.scheduled when !ended => l10n.passesStarts(
        DateFormat.E(localeTag).add_Hm().format(p.startsAt.toLocal()),
      ),
      PassStatus.active when !ended => l10n.passEndsIn(
        date,
        formatTimeLeft(l10n, remaining),
      ),
      PassStatus.expired => l10n.passesExpiredAt(date),
      _ => l10n.passesEndedAt(date),
    };
    final headline = ended
        ? l10n.passEnded
        : effectiveStatus == PassStatus.scheduled
        ? l10n.passesStatusScheduled
        : capped
        ? l10n.dashboardTimeLeft(formatMegabytes(l10n, left))
        : l10n.dashboardTimeLeft(formatTimeLeft(l10n, remaining));
    return PassSummary(
      headline: headline,
      capText: capped ? l10n.passOfCap(formatMegabytes(l10n, cap)) : null,
      fractionLeft: fraction,
      endsText: ends,
      tier: tier,
      effectiveStatus: effectiveStatus,
    );
  }
}
