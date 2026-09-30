import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/free_wifi_session.dart';

/// IMPORTANT — the cap and session rules can NOT be enforced on the device.
/// Anything the app stores or measures locally (counts, timestamps, even
/// secure storage) can be reset by clearing app data or reinstalling. The
/// mock implementation adds tamper-aware timekeeping as a deterrent only.
///
/// Real enforcement requires a server entitlement API:
///  * the server owns the daily counter (per account/device) and its clock,
///  * the rewarded ad is verified server-to-server (ad-network SSV callback),
///    and only then does the server mint the session,
///  * this interface's methods map 1:1 onto that API, so the backend
///    implementation replaces the mock without UI changes. Real ad
///    networks (e.g. AdMob) also need unit ids this app does not have yet.
abstract class FreeWifiRepository {
  static const maxAdsPerDay = 3;

  Future<Either<Failure, int>> getAdsWatchedToday();

  Future<Either<Failure, FreeWifiSession?>> getActiveSession();

  /// Records that an ad was watched (for later upsell analysis — e.g. a
  /// customer who repeatedly relies on free WiFi is a strong candidate
  /// for a data-plan offer) and grants a new session. A rejected request
  /// (cap reached, session already active, device clock looks tampered
  /// with) must not change the counter.
  Future<Either<Failure, FreeWifiSession>> recordAdWatchedAndGrantSession();

  /// Clears locally held state. The active session is always dropped; the
  /// daily counter only when [includeDailyCounter] (account deletion), so
  /// simply logging out cannot be used to reset the cap.
  Future<void> reset({bool includeDailyCounter = false});
}
