import 'package:equatable/equatable.dart';

/// `HotspotPublicOut.status`: only these two are ever listed publicly.
enum HotspotStatus { live, maintenance }

class WifiHotspot extends Equatable {
  const WifiHotspot({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.status = HotspotStatus.live,
    this.address,
  });

  final String id;
  final String name;
  final double latitude;
  final double longitude;
  final HotspotStatus status;

  /// `address_text`; null when the provider has not entered one.
  final String? address;

  bool get isUnderMaintenance => status == HotspotStatus.maintenance;

  @override
  List<Object?> get props => [id, name, latitude, longitude, status, address];
}
