import 'package:geocoding/geocoding.dart';

/// Turns device coordinates into a real, human-readable street address
/// using the platform's built-in geocoder (free, no API key). Returns a
/// single best-guess address — a list of alternative nearby suggestions
/// (the way Google Maps offers several candidates) would need the Google
/// Places API, which requires a billing-enabled API key this app doesn't
/// have configured.
Future<String?> reverseGeocode(double latitude, double longitude) async {
  try {
    final placemarks = await Geocoding().placemarkFromCoordinates(latitude, longitude);
    if (placemarks.isEmpty) return null;
    final p = placemarks.first;
    final parts = <String>[
      if (p.street != null && p.street!.trim().isNotEmpty) p.street!,
      if (p.subLocality != null && p.subLocality!.trim().isNotEmpty) p.subLocality!,
      if (p.locality != null && p.locality!.trim().isNotEmpty) p.locality!,
      if (p.administrativeArea != null && p.administrativeArea!.trim().isNotEmpty) p.administrativeArea!,
      if (p.postalCode != null && p.postalCode!.trim().isNotEmpty) p.postalCode!,
    ];
    return parts.isEmpty ? null : parts.join(', ');
  } catch (_) {
    return null;
  }
}
