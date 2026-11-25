import 'package:equatable/equatable.dart';

/// A place the customer chose (a tapped pin, a picked address or their own
/// location). It is personal data: [toString] never prints it, so a log line or
/// a test failure message cannot leak it, and it is only ever held in memory.
class GeoPoint extends Equatable {
  const GeoPoint(this.lat, this.lon);

  final double lat;
  final double lon;

  @override
  List<Object?> get props => [lat, lon];

  @override
  String toString() => 'GeoPoint(redacted)';
}
