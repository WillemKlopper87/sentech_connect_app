import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';

/// Real implementation queries Sentech's hotspot inventory API (open
/// integration point, same status as coverage/CPE telemetry).
abstract class WifiHotspotsRepository {
  Future<Either<Failure, List<WifiHotspot>>> getHotspots();
}
