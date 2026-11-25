import 'package:equatable/equatable.dart';

/// What the public check says about a point (`GET /v1/coverage/check`, result
/// shape v2). Every field is the server's answer: the app never computes a
/// band, a speed or a verdict. An enum-like field with a value the app does
/// not know reads as `unknown` (the card then shows a neutral label), never as
/// a guess and never as a crash.

enum CoverageAnswer { covered, planned, notCovered, unknown }

enum CoverageTechnology { fiveG, lte, unknown }

enum OptionKind { covered, planned, unknown }

enum CoverageConfidence { high, medium, low, unknown }

enum MeasureDirection { downlink, uplink, unknown }

enum DistanceBand { under5Km, from5To20Km, from20To50Km, over50Km, unknown }

/// A speed range in Mbps the server stated (`min <= max`, both >= 0).
class SpeedRange extends Equatable {
  const SpeedRange(this.minMbps, this.maxMbps);

  final int minMbps;
  final int maxMbps;

  @override
  List<Object?> get props => [minMbps, maxMbps];
}

/// The band of an option: present only when the server decided to show one.
/// [key] is the server's key (`excellent`, `good`, `fair`, `basic`, `none`, or
/// something newer: the card then shows no band words).
class OptionBand extends Equatable {
  const OptionBand({required this.key, required this.rank, required this.notify});

  final String key;
  final int rank;
  final bool notify;

  @override
  List<Object?> get props => [key, rank, notify];
}

/// One technology that has a covered or planned area at the point.
class CoverageOption extends Equatable {
  const CoverageOption({
    required this.technology,
    required this.technologyRaw,
    required this.kind,
    required this.confidence,
    required this.nearBoundary,
    required this.notifyAvailable,
    required this.measureDirection,
    this.band,
    this.typicalDown,
    this.busyHourDown,
    this.expectedDate,
    this.measureLabelKey,
    this.sourceKey,
    this.datasetVersion,
    this.releaseLabel,
    this.releaseDate,
  });

  final CoverageTechnology technology;

  /// The technology string as the server sent it, for a neutral label when
  /// [technology] is `unknown`.
  final String technologyRaw;
  final OptionKind kind;
  final OptionBand? band;
  final SpeedRange? typicalDown;
  final SpeedRange? busyHourDown;
  final CoverageConfidence confidence;
  final bool nearBoundary;
  final bool notifyAvailable;

  /// A calendar date (UTC midnight, never shifted): read year, month and day only.
  final DateTime? expectedDate;
  final MeasureDirection measureDirection;

  /// `dataset.measure_label_key` (`coverage.measure.downlink` and so on).
  final String? measureLabelKey;

  /// `dataset.source_label`, a message key (`coverage.source.*`).
  final String? sourceKey;
  final int? datasetVersion;
  final String? releaseLabel;
  final DateTime? releaseDate;

  /// A figure is shown only when the server carried one for a downlink basis.
  bool get hasFigures => typicalDown != null || busyHourDown != null;

  @override
  List<Object?> get props => [
    technology,
    technologyRaw,
    kind,
    band,
    typicalDown,
    busyHourDown,
    confidence,
    nearBoundary,
    notifyAvailable,
    expectedDate,
    measureDirection,
    measureLabelKey,
    sourceKey,
    datasetVersion,
    releaseLabel,
    releaseDate,
  ];
}

/// Only when there is no option: the technology of the nearest covered area
/// and a coarse distance band.
class CoverageNearest extends Equatable {
  const CoverageNearest({required this.technology, required this.technologyRaw, required this.distance});

  final CoverageTechnology technology;
  final String technologyRaw;
  final DistanceBand distance;

  @override
  List<Object?> get props => [technology, technologyRaw, distance];
}

class CoverageCheck extends Equatable {
  const CoverageCheck({
    required this.status,
    required this.tenant,
    required this.shapeVersion,
    required this.options,
    required this.disclaimerKeys,
    required this.waitlistAvailable,
    this.primaryIndex,
    this.nearest,
    this.datasetVersion,
  });

  final CoverageAnswer status;
  final String tenant;

  /// 2 for the options shape; 1 when the server did not say (an older server).
  final int shapeVersion;
  final List<CoverageOption> options;

  /// Index into [options] of the one to show first; null when the server named none (or an invalid index).
  final int? primaryIndex;
  final CoverageNearest? nearest;
  final List<String> disclaimerKeys;

  /// The legacy top-level flag, kept for an answer with no options.
  final bool waitlistAvailable;
  final int? datasetVersion;

  CoverageOption? get primary {
    if (options.isEmpty) return null;
    final index = primaryIndex;
    return index == null ? options.first : options[index];
  }

  /// The release label and date of the answer shown (primary option's dataset).
  String? get releaseLabel => primary?.releaseLabel;
  DateTime? get releaseDate => primary?.releaseDate;

  /// Whether any option is covered (the customer can go on to the plans).
  bool get hasCoveredOption => options.any((o) => o.kind == OptionKind.covered);

  /// Whether the notify-me action may be offered at all: the server allows it
  /// for at least one option, or (an answer with no options) by the legacy flag.
  bool get notifyAvailable => options.isEmpty ? waitlistAvailable : options.any((o) => o.notifyAvailable);

  @override
  List<Object?> get props => [
    status,
    tenant,
    shapeVersion,
    options,
    primaryIndex,
    nearest,
    disclaimerKeys,
    waitlistAvailable,
    datasetVersion,
  ];
}
