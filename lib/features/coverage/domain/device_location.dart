/// The phone's own position, read once when the customer taps "use my
/// location", behind the OS permission prompt. The platform implementation is
/// `GeolocatorDeviceLocation`; tests use a fake. The position is never stored.
abstract interface class DeviceLocationService {
  Future<DeviceLocationResult> current();
}

sealed class DeviceLocationResult {
  const DeviceLocationResult();
}

class LocationFound extends DeviceLocationResult {
  const LocationFound({required this.lat, required this.lon});

  final double lat;
  final double lon;

  @override
  String toString() => 'LocationFound(redacted)';
}

/// Location services (GPS) are switched off on the phone.
class LocationServiceOff extends DeviceLocationResult {
  const LocationServiceOff();
}

/// The customer said no to the permission prompt (they can be asked again).
class LocationDenied extends DeviceLocationResult {
  const LocationDenied();
}

/// Permission is denied for good (or "while using" was revoked): only the phone's settings can change it.
class LocationDeniedForever extends DeviceLocationResult {
  const LocationDeniedForever();
}

/// The position could not be read (no fix, a timeout, a platform error).
class LocationFailed extends DeviceLocationResult {
  const LocationFailed();
}
