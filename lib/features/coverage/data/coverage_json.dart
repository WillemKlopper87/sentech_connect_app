import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_meta.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';

/// Lenient decoders for the public coverage answers. A field that is missing,
/// null or of an unexpected type reads as absent; an enum-like value the app
/// does not know reads as `unknown`. Nothing here throws for a newer or older
/// server, and nothing is derived: a band or a speed appears only when the
/// response carried it. The contract test lists every current value, so a new
/// platform value is still caught in CI.

Map<String, Object?>? _map(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;

String? _str(Object? value) => value is String ? value : null;

int? _int(Object? value) => value is int ? value : null;

bool _bool(Object? value) => value is bool ? value : false;

double? _double(Object? value) => value is num && value.isFinite ? value.toDouble() : null;

DateTime? _date(Object? value) {
  if (value is! String) return null;
  try {
    return parseApiDate(value);
  } on FormatException {
    return null;
  }
}

DateTime? _instant(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;

CoverageTechnology coverageTechnologyFromApi(Object? value) => switch (value) {
  '5g' => CoverageTechnology.fiveG,
  'lte' => CoverageTechnology.lte,
  _ => CoverageTechnology.unknown,
};

CoverageAnswer coverageAnswerFromApi(Object? value) => switch (value) {
  'covered' => CoverageAnswer.covered,
  'planned' => CoverageAnswer.planned,
  'not_covered' => CoverageAnswer.notCovered,
  _ => CoverageAnswer.unknown,
};

OptionKind optionKindFromApi(Object? value) => switch (value) {
  'covered' => OptionKind.covered,
  'planned' => OptionKind.planned,
  _ => OptionKind.unknown,
};

CoverageConfidence coverageConfidenceFromApi(Object? value) => switch (value) {
  'high' => CoverageConfidence.high,
  'medium' => CoverageConfidence.medium,
  'low' => CoverageConfidence.low,
  _ => CoverageConfidence.unknown,
};

MeasureDirection measureDirectionFromApi(Object? value) => switch (value) {
  'downlink' => MeasureDirection.downlink,
  'uplink' => MeasureDirection.uplink,
  _ => MeasureDirection.unknown,
};

DistanceBand distanceBandFromApi(Object? value) => switch (value) {
  'under 5 km' => DistanceBand.under5Km,
  '5 to 20 km' => DistanceBand.from5To20Km,
  '20 to 50 km' => DistanceBand.from20To50Km,
  'over 50 km' => DistanceBand.over50Km,
  _ => DistanceBand.unknown,
};

MatchPrecision matchPrecisionFromApi(Object? value) => switch (value) {
  'address' => MatchPrecision.address,
  'street' => MatchPrecision.street,
  'area' => MatchPrecision.area,
  _ => MatchPrecision.unknown,
};

/// Both ends must be whole numbers with `0 <= min <= max`; anything else is no figure.
SpeedRange? speedRangeFromJson(Object? value) {
  final json = _map(value);
  if (json == null) return null;
  final low = _int(json['min_mbps']);
  final high = _int(json['max_mbps']);
  if (low == null || high == null || low < 0 || high < low) return null;
  return SpeedRange(low, high);
}

OptionBand? _band(Object? value) {
  final json = _map(value);
  final key = _str(json?['key']);
  if (json == null || key == null || key.isEmpty) return null;
  return OptionBand(key: key, rank: _int(json['rank']) ?? 0, notify: _bool(json['notify']));
}

CoverageOption? _option(Object? value) {
  final json = _map(value);
  if (json == null) return null;
  final raw = _str(json['technology']) ?? '';
  final kind = optionKindFromApi(json['kind']);
  final dataset = _map(json['dataset']);
  final direction = measureDirectionFromApi(dataset?['measure_direction']);
  // The server withholds a band and figures for a planned option and for a
  // dataset that is not downlink; if one ever arrived anyway the app shows none
  // (it never presents an uplink or unknown basis as a download speed).
  final figuresAllowed = kind == OptionKind.covered && direction == MeasureDirection.downlink;
  return CoverageOption(
    technology: coverageTechnologyFromApi(raw),
    technologyRaw: raw,
    kind: kind,
    band: kind == OptionKind.planned ? null : _band(json['band']),
    typicalDown: figuresAllowed ? speedRangeFromJson(json['typical_down']) : null,
    busyHourDown: figuresAllowed ? speedRangeFromJson(json['busy_hour_down']) : null,
    confidence: coverageConfidenceFromApi(json['confidence']),
    nearBoundary: _bool(json['near_boundary']),
    notifyAvailable: _bool(json['notify_available']),
    expectedDate: _date(json['expected_date']),
    measureDirection: direction,
    measureLabelKey: _str(dataset?['measure_label_key']),
    sourceKey: _str(dataset?['source_label']),
    datasetVersion: _int(dataset?['version']),
    releaseLabel: _str(dataset?['release_label']),
    releaseDate: _date(dataset?['release_date']),
  );
}

CoverageNearest? _nearest(Object? value) {
  final json = _map(value);
  if (json == null) return null;
  final raw = _str(json['technology']) ?? '';
  return CoverageNearest(
    technology: coverageTechnologyFromApi(raw),
    technologyRaw: raw,
    distance: distanceBandFromApi(json['distance_band']),
  );
}

CoverageCheck coverageCheckFromJson(Map<String, Object?> json) {
  final options = <CoverageOption>[];
  final rawOptions = json['options'];
  if (rawOptions is List) {
    for (final item in rawOptions) {
      final option = _option(item);
      if (option != null) options.add(option);
    }
  }
  final index = json['primary_index'];
  // The index counts the server's list; skipping an unreadable option would
  // shift it, so it is honoured only when nothing was skipped.
  final skipped = rawOptions is List && rawOptions.length != options.length;
  final primary = index is int && !skipped && index >= 0 && index < options.length ? index : null;
  final keys = json['disclaimer_keys'];
  return CoverageCheck(
    status: coverageAnswerFromApi(json['status']),
    tenant: _str(json['tenant']) ?? '',
    shapeVersion: _int(json['shape_version']) ?? 1,
    options: options,
    primaryIndex: primary,
    nearest: options.isEmpty ? _nearest(json['nearest']) : null,
    disclaimerKeys: keys is List ? [for (final k in keys) if (k is String) k] : const [],
    waitlistAvailable: _bool(json['waitlist_available']),
    datasetVersion: _int(json['dataset_version']),
  );
}

GeoBounds? _bounds(Object? value) {
  if (value is! List || value.length != 4) return null;
  final numbers = [for (final v in value) _double(v)];
  if (numbers.any((n) => n == null)) return null;
  return GeoBounds(west: numbers[0]!, south: numbers[1]!, east: numbers[2]!, north: numbers[3]!);
}

CoverageMeta coverageMetaFromJson(Map<String, Object?> json) {
  final layers = <CoverageLayer>[];
  final rawLayers = json['layers'];
  if (rawLayers is List) {
    for (final item in rawLayers) {
      final layer = _map(item);
      final name = _str(layer?['name']);
      final template = _str(layer?['url_template']);
      if (layer == null || name == null || template == null) continue;
      layers.add(CoverageLayer(name: name, version: _str(layer['version']) ?? '', urlTemplate: template));
    }
  }
  return CoverageMeta(
    datasetVersion: _int(json['dataset_version']),
    datasetActivatedAt: _instant(json['dataset_activated_at']),
    bounds: _bounds(json['bounds']),
    waitlistConsentVersion: _str(json['waitlist_consent_version']),
    coverageArrivedConsentVersion: _str(json['coverage_arrived_consent_version']),
    attribution: _str(json['attribution']),
    minZoom: _int(json['min_zoom']),
    maxZoom: _int(json['max_zoom']),
    layers: layers,
  );
}

/// The matches of `POST /v1/coverage/address` or `GET /v1/geocode/search`
/// (which names `kind` instead of `precision`: read as an unknown precision).
/// A hit without a label or with coordinates outside the globe is skipped.
List<GeocodeMatch> geocodeMatchesFromJson(Map<String, Object?> json) {
  final matches = <GeocodeMatch>[];
  final results = json['results'];
  if (results is! List) return matches;
  for (final item in results) {
    final hit = _map(item);
    final label = _str(hit?['label']);
    final lat = _double(hit?['lat']);
    final lon = _double(hit?['lon']);
    if (hit == null || label == null || label.isEmpty || lat == null || lon == null) continue;
    if (lat < -90 || lat > 90 || lon < -180 || lon > 180) continue;
    matches.add(GeocodeMatch(label: label, lat: lat, lon: lon, precision: matchPrecisionFromApi(hit['precision'])));
  }
  return matches;
}

AddressSearchResult addressSearchResultFromJson(Map<String, Object?> json) => AddressSearchResult(
  matches: geocodeMatchesFromJson(json),
  matched: json['matched'] == null ? null : matchPrecisionFromApi(json['matched']),
);
