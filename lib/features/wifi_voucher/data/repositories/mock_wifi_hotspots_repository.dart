import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/wifi_hotspots_repository.dart';

/// Mock hotspots scattered around eMbalenhle, Mpumalanga — the 5G FWA
/// pilot area named in docs/reconciled-spec.md.
class MockWifiHotspotsRepository implements WifiHotspotsRepository {
  static const _hotspots = [
    WifiHotspot(id: 'hs_1', name: 'eMbalenhle Community Hall', latitude: -26.6873, longitude: 29.0721),
    WifiHotspot(id: 'hs_2', name: 'Lifalethu Shopping Centre', latitude: -26.6935, longitude: 29.0668),
    WifiHotspot(id: 'hs_3', name: 'Sentech Sender Technology Park', latitude: -26.1234, longitude: 27.9345),
    WifiHotspot(id: 'hs_4', name: 'eMbalenhle Taxi Rank', latitude: -26.6801, longitude: 29.0789),
    WifiHotspot(id: 'hs_5', name: 'Secunda Library', latitude: -26.5507, longitude: 29.1727),
  ];

  @override
  Future<Either<Failure, List<WifiHotspot>>> getHotspots() async {
    await Future.delayed(const Duration(milliseconds: 300));
    return const Right(_hotspots);
  }
}
