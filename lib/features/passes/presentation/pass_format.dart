import 'package:sentech_connect_app/features/passes/domain/entities/pass.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

/// Remaining time, clamped at zero, in the customer's language.
String formatTimeLeft(AppLocalizations l10n, Duration d) {
  if (d.isNegative) d = Duration.zero;
  if (d.inDays >= 1) {
    return l10n.durationDaysHours(d.inDays, d.inHours.remainder(24));
  }
  if (d.inHours >= 1) {
    return l10n.durationHoursMinutes(d.inHours, d.inMinutes.remainder(60));
  }
  return l10n.durationMinutes(d.inMinutes);
}

String formatMegabytes(AppLocalizations l10n, num mb) {
  if (mb < 0) mb = 0;
  if (mb >= 1024) {
    final gb = mb / 1024;
    return l10n.sizeGigabytes(
      gb.toStringAsFixed(gb == gb.roundToDouble() ? 0 : 1),
    );
  }
  return l10n.sizeMegabytes(mb.round().toString());
}

/// "3.8 GB of 5 GB left" for a capped pass; null when the pass is uncapped.
/// Never negative, even if the server reports more usage than the cap.
String? dataLeftText(AppLocalizations l10n, Pass pass) {
  final cap = pass.dataMb;
  if (cap == null) return null;
  final left = (cap - pass.usedBytes / (1024 * 1024)).clamp(
    0,
    cap < 0 ? 0 : cap,
  );
  return l10n.dashboardDataLeft(
    formatMegabytes(l10n, left),
    formatMegabytes(l10n, cap),
  );
}
