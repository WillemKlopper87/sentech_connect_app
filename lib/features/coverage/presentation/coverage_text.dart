import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// App copy for the platform's coverage answer. The platform sends KEYS (a band
/// key, a disclaimer key, a source key, a direction key), never free text; each
/// maps to the app's own words. A key the app has no words for maps to null (or
/// to a neutral generic text), never to the raw key and never to a guess.

String technologyName(AppLocalizations l10n, CoverageTechnology technology, String raw) => switch (technology) {
  CoverageTechnology.fiveG => l10n.coverageTech5g,
  CoverageTechnology.lte => l10n.coverageTechLte,
  // A technology the app does not know is always the neutral "Network": the server's string is never shown.
  CoverageTechnology.unknown => l10n.coverageTechUnknown,
};

/// The band title, or null for a band key the app has no words for (the card then
/// shows the plain "coverage is predicted here" instead).
String? bandTitle(AppLocalizations l10n, String key) => switch (key) {
  'excellent' => l10n.coverageBandExcellentTitle,
  'good' => l10n.coverageBandGoodTitle,
  'fair' => l10n.coverageBandFairTitle,
  'basic' => l10n.coverageBandBasicTitle,
  'none' => l10n.coverageBandNoneTitle,
  _ => null,
};

String? bandText(AppLocalizations l10n, String key) => switch (key) {
  'excellent' => l10n.coverageBandExcellentText,
  'good' => l10n.coverageBandGoodText,
  'fair' => l10n.coverageBandFairText,
  'basic' => l10n.coverageBandBasicText,
  'none' => l10n.coverageBandNoneText,
  _ => null,
};

/// What the figures of an option measure. A missing or unfamiliar key reads as
/// "we do not know", never as download.
String measureText(AppLocalizations l10n, CoverageOption option) => switch (option.measureLabelKey) {
  'coverage.measure.downlink' when option.measureDirection == MeasureDirection.downlink => l10n.coverageMeasureDownlink,
  'coverage.measure.uplink' => l10n.coverageMeasureUplink,
  _ => l10n.coverageMeasureUnknown,
};

String? confidenceText(AppLocalizations l10n, CoverageConfidence confidence) => switch (confidence) {
  CoverageConfidence.high => l10n.coverageConfidenceHigh,
  CoverageConfidence.medium => l10n.coverageConfidenceMedium,
  CoverageConfidence.low => l10n.coverageConfidenceLow,
  CoverageConfidence.unknown => null,
};

String? sourceText(AppLocalizations l10n, String? key) => switch (key) {
  'coverage.source.technology_partner' => l10n.coverageSourceTechnologyPartner,
  'coverage.source.network_rf_planning' => l10n.coverageSourceNetworkRfPlanning,
  'coverage.source.isp_planning' => l10n.coverageSourceIspPlanning,
  'coverage.source.drive_test' => l10n.coverageSourceDriveTest,
  _ => null,
};

/// The notice for a server disclaimer key, or null for a key the app has no text for.
String? disclaimerText(AppLocalizations l10n, String key) => switch (key) {
  'coverage.estimate' => l10n.coverageDisclaimerEstimate,
  'coverage.indoor' => l10n.coverageDisclaimerIndoor,
  'coverage.planned_date' => l10n.coverageDisclaimerPlannedDate,
  'commerce.cooling_off' => l10n.coverageDisclaimerCoolingOff,
  _ => null,
};

/// The distance words for the nearest coverage, or null for a band the app does not know.
String? nearestText(AppLocalizations l10n, CoverageNearest nearest) {
  final technology = technologyName(l10n, nearest.technology, nearest.technologyRaw);
  return switch (nearest.distance) {
    DistanceBand.under5Km => l10n.coverageNearestUnder5(technology),
    DistanceBand.from5To20Km => l10n.coverageNearestFrom5To20(technology),
    DistanceBand.from20To50Km => l10n.coverageNearestFrom20To50(technology),
    DistanceBand.over50Km => l10n.coverageNearestOver50(technology),
    DistanceBand.unknown => null,
  };
}

/// "March 2027": a planned option never promises a day.
String plannedMonth(BuildContext context, DateTime date) =>
    DateFormat.yMMMM(Localizations.localeOf(context).toLanguageTag()).format(DateTime(date.year, date.month));

/// The release line of the footer: label and date, label, date, or the dataset version.
String releaseText(BuildContext context, {String? label, DateTime? date, int? version}) {
  final l10n = context.l10n;
  final day = date == null ? null : DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(DateTime(date.year, date.month, date.day));
  if (label != null && label.isNotEmpty && day != null) return l10n.coverageFooterRelease(label, day);
  if (label != null && label.isNotEmpty) return l10n.coverageFooterReleaseLabel(label);
  if (day != null) return l10n.coverageFooterReleaseDate(day);
  return version == null ? '' : l10n.coverageFooterVersion(version.toString());
}

/// Plain words for a failure on the coverage screens: offline, then the typed copy, then the
/// message-based copy (the platform's own customer wording for a refusal).
String coverageFailureText(AppLocalizations l10n, Failure failure) {
  if (failure is NetworkFailure) return l10n.failureYouReOfflineCheckYourConnection;
  return typedFailureText(l10n, failure) ?? localizedFailureText(l10n, failure.message);
}
