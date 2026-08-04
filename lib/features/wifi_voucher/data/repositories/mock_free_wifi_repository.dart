import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/free_wifi_session.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

class MockFreeWifiRepository implements FreeWifiRepository {
  @override
  Future<Either<Failure, int>> getAdsWatchedToday() async {
    return Right(await AppPreferences.getAdsWatchedToday());
  }

  @override
  Future<Either<Failure, FreeWifiSession?>> getActiveSession() async {
    final saved = await AppPreferences.loadFreeWifiSession();
    if (saved == null) return const Right(null);
    final (grantedAt, durationMinutes) = saved;
    final session = FreeWifiSession(
      grantedAt: grantedAt,
      durationMinutes: durationMinutes,
      dataAllowanceMb: 500,
    );
    if (session.isExpired) {
      await AppPreferences.clearFreeWifiSession();
      return const Right(null);
    }
    return Right(session);
  }

  @override
  Future<Either<Failure, FreeWifiSession>> recordAdWatchedAndGrantSession() async {
    final watchedToday = await AppPreferences.recordAdWatched();
    if (watchedToday > FreeWifiRepository.maxAdsPerDay) {
      return const Left(ValidationFailure("You've reached today's free WiFi limit."));
    }
    // Grants somewhere in the 30-60 minute range requested; a fixed 45
    // minutes here since there's no real ad-network reward tier to vary it.
    const durationMinutes = 45;
    final grantedAt = DateTime.now();
    await AppPreferences.saveFreeWifiSession(grantedAt, durationMinutes);
    return Right(FreeWifiSession(
      grantedAt: grantedAt,
      durationMinutes: durationMinutes,
      dataAllowanceMb: 500,
    ));
  }
}
