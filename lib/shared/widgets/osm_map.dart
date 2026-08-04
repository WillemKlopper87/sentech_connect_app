import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

/// South Africa's rough centre — used as the default view before a
/// specific location (device GPS or a typed/geocoded address) is known.
const southAfricaCenter = LatLng(-28.4793, 24.6727);

/// A real, interactive OpenStreetMap view (free, no API key) used for
/// both the coverage-check address pin and the WiFi hotspot locator.
///
/// Note: this fetches OSM tiles over the network on demand. Caching
/// those tiles for offline use (e.g. "pre-load South Africa once on
/// WiFi, refresh monthly") is a real, separate engineering project —
/// tile storage budgets, background sync scheduling, cache invalidation
/// — worth scoping on its own once this basic map has been reviewed,
/// rather than half-building it here.
class OsmMap extends StatelessWidget {
  const OsmMap({
    super.key,
    required this.center,
    this.zoom = 14,
    this.markers = const [],
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
  });

  final LatLng center;
  final double zoom;
  final List<Marker> markers;
  final BorderRadius borderRadius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: FlutterMap(
        options: MapOptions(initialCenter: center, initialZoom: zoom),
        children: [
          TileLayer(
            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
            userAgentPackageName: 'za.co.sentech.sentech_connect_app',
          ),
          if (markers.isNotEmpty) MarkerLayer(markers: markers),
        ],
      ),
    );
  }
}

/// A simple pin marker in the app's brand red (matching the CI manual's
/// map-pin usage elsewhere), sized for a 40x40 marker slot.
Marker brandPin(LatLng point, {Color color = const Color(0xFFED1C24)}) {
  return Marker(
    point: point,
    width: 40,
    height: 40,
    child: Icon(Icons.location_on, color: color, size: 36),
  );
}
