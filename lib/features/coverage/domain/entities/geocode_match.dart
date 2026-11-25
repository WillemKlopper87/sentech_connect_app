import 'package:equatable/equatable.dart';

enum MatchPrecision { address, street, area, unknown }

/// A place the platform found for a typed address. The label and the
/// coordinates are personal data: [toString] never prints them, so a log line
/// or a test failure message cannot leak them.
class GeocodeMatch extends Equatable {
  const GeocodeMatch({required this.label, required this.lat, required this.lon, this.precision = MatchPrecision.unknown});

  final String label;
  final double lat;
  final double lon;
  final MatchPrecision precision;

  @override
  List<Object?> get props => [label, lat, lon, precision];

  @override
  String toString() => 'GeocodeMatch(${precision.name})';
}

/// The answer to an address search: the matches and the step of the platform's
/// fallback ladder that produced them (null for the older search, or none).
class AddressSearchResult extends Equatable {
  const AddressSearchResult({required this.matches, this.matched});

  final List<GeocodeMatch> matches;
  final MatchPrecision? matched;

  @override
  List<Object?> get props => [matches, matched];
}
