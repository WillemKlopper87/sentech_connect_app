import 'package:geolocator/geolocator.dart';
import 'package:sentech_connect_app/features/coverage/domain/device_location.dart';

/// Reads the position with `geolocator`. Coverage needs a place within about
/// 100 m, so a medium-accuracy fix is asked for (less battery and a coarser
/// footprint than a high-accuracy one), with a timeout.
class GeolocatorDeviceLocation implements DeviceLocationService {
  const GeolocatorDeviceLocation({this.timeout = const Duration(seconds: 20)});

  final Duration timeout;

  @override
  Future<void> openAppSettings() async {
    await Geolocator.openAppSettings();
  }

  @override
  Future<void> openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  @override
  Future<DeviceLocationResult> current() async {
    try {
      if (!await Geolocator.isLocationServiceEnabled()) return const LocationServiceOff();
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.deniedForever) return const LocationDeniedForever();
      if (permission == LocationPermission.denied || permission == LocationPermission.unableToDetermine) {
        return const LocationDenied();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: LocationSettings(accuracy: LocationAccuracy.medium, timeLimit: timeout),
      );
      return LocationFound(lat: position.latitude, lon: position.longitude);
    } on Object {
      // No detail is kept: an error message could carry a position.
      return const LocationFailed();
    }
  }
}
