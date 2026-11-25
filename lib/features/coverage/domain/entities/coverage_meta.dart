import 'package:equatable/equatable.dart';

/// `[west, south, east, north]` in WGS84: the service area the server checks.
class GeoBounds extends Equatable {
  const GeoBounds({required this.west, required this.south, required this.east, required this.north});

  final double west;
  final double south;
  final double east;
  final double north;

  bool contains({required double lat, required double lon}) => lon >= west && lon <= east && lat >= south && lat <= north;

  @override
  List<Object?> get props => [west, south, east, north];
}

class CoverageLayer extends Equatable {
  const CoverageLayer({required this.name, required this.version, required this.urlTemplate});

  final String name;
  final String version;
  final String urlTemplate;

  @override
  List<Object?> get props => [name, version, urlTemplate];
}

/// `GET /v1/coverage/meta`: the dataset version in force, the service area, the
/// consent text versions the notify-me form must echo, and the attribution.
class CoverageMeta extends Equatable {
  const CoverageMeta({
    this.datasetVersion,
    this.datasetActivatedAt,
    this.bounds,
    this.waitlistConsentVersion,
    this.coverageArrivedConsentVersion,
    this.attribution,
    this.minZoom,
    this.maxZoom,
    this.layers = const [],
  });

  /// Null when the provider has no active dataset.
  final int? datasetVersion;
  final DateTime? datasetActivatedAt;
  final GeoBounds? bounds;
  final String? waitlistConsentVersion;
  final String? coverageArrivedConsentVersion;
  final String? attribution;
  final int? minZoom;
  final int? maxZoom;
  final List<CoverageLayer> layers;

  /// The notify-me form needs the current consent version of both purposes.
  bool get canOfferNotify => (waitlistConsentVersion ?? '').isNotEmpty && (coverageArrivedConsentVersion ?? '').isNotEmpty;

  @override
  List<Object?> get props => [
    datasetVersion,
    datasetActivatedAt,
    bounds,
    waitlistConsentVersion,
    coverageArrivedConsentVersion,
    attribution,
    minZoom,
    maxZoom,
    layers,
  ];
}
