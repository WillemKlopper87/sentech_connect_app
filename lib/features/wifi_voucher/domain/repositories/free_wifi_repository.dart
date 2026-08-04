import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/free_wifi_session.dart';

/// Real implementation would show a real rewarded ad (e.g. Google AdMob —
/// needs a real ad account/unit IDs this app doesn't have configured),
/// then grant the session server-side so it can be enforced across
/// devices. This mock enforces the daily cap and session locally only.
abstract class FreeWifiRepository {
  static const maxAdsPerDay = 3;

  Future<Either<Failure, int>> getAdsWatchedToday();

  Future<Either<Failure, FreeWifiSession?>> getActiveSession();

  /// Records that an ad was watched (for later upsell analysis — e.g. a
  /// customer who repeatedly relies on free WiFi is a strong candidate
  /// for a data-plan offer) and grants a new session.
  Future<Either<Failure, FreeWifiSession>> recordAdWatchedAndGrantSession();
}
