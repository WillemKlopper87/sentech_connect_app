import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/mock_free_wifi_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

void main() {
  late InMemorySecureStore store;
  late FakePlatformClock clock;
  late MockFreeWifiRepository repo;

  setUp(() {
    store = InMemorySecureStore();
    clock = FakePlatformClock(start: DateTime(2026, 9, 30, 10));
    repo = MockFreeWifiRepository(store, clock: clock);
  });

  Future<int> adsToday() async => (await repo.getAdsWatchedToday()).getOrElse((_) => -1);

  /// Watch one ad and let the 45-minute session run out.
  Future<void> burnOneAd() async {
    expect((await repo.recordAdWatchedAndGrantSession()).isRight(), isTrue);
    clock.advance(const Duration(minutes: 46));
  }

  test('grants a 45 minute session and counts the ad', () async {
    final session = (await repo.recordAdWatchedAndGrantSession()).getOrElse((_) => throw StateError('x'));
    expect(session.durationMinutes, 45);
    expect(await adsToday(), 1);
    expect((await repo.getActiveSession()).getOrElse((_) => null), isNotNull);
  });

  test('the 4th request is rejected WITHOUT incrementing the counter', () async {
    for (var i = 0; i < FreeWifiRepository.maxAdsPerDay; i++) {
      await burnOneAd();
    }
    expect(await adsToday(), 3);

    final fourth = await repo.recordAdWatchedAndGrantSession();
    expect(fourth.isLeft(), isTrue);
    expect(await adsToday(), 3); // regression: used to become 4 before the check
    expect((await repo.getActiveSession()).getOrElse((_) => null), isNull);
  });

  test('a second grant while a session is running is refused and not counted', () async {
    await repo.recordAdWatchedAndGrantSession();
    expect((await repo.recordAdWatchedAndGrantSession()).isLeft(), isTrue);
    expect(await adsToday(), 1);
  });

  test('the session expires on schedule', () async {
    await repo.recordAdWatchedAndGrantSession();
    clock.advance(const Duration(minutes: 44));
    expect((await repo.getActiveSession()).getOrElse((_) => null), isNotNull);
    clock.advance(const Duration(minutes: 2));
    expect((await repo.getActiveSession()).getOrElse((_) => null), isNull);
  });

  test('moving the wall clock forward does not shorten or extend the running session (same boot)', () async {
    await repo.recordAdWatchedAndGrantSession();
    clock.advance(const Duration(minutes: 10));
    clock.setWall(clock.wallNow().add(const Duration(hours: 5))); // user jumps the clock ahead
    final session = (await repo.getActiveSession()).getOrElse((_) => null);
    expect(session, isNotNull);
    expect(session!.elapsedAtLoad, const Duration(minutes: 10));
  });

  test('moving the clock to the next day does not reset the daily cap (same boot)', () async {
    for (var i = 0; i < FreeWifiRepository.maxAdsPerDay; i++) {
      await burnOneAd();
    }
    clock.setWall(clock.wallNow().add(const Duration(days: 1)));
    expect(await adsToday(), 3);
    expect((await repo.recordAdWatchedAndGrantSession()).isLeft(), isTrue);
  });

  test('the cap resets on a genuinely new day (time really passed)', () async {
    for (var i = 0; i < FreeWifiRepository.maxAdsPerDay; i++) {
      await burnOneAd();
    }
    clock.advance(const Duration(hours: 24));
    expect(await adsToday(), 0);
    expect((await repo.recordAdWatchedAndGrantSession()).isRight(), isTrue);
  });

  test('a wall clock moved backwards is detected and blocks new grants', () async {
    await burnOneAd();
    clock.setWall(clock.wallNow().subtract(const Duration(days: 1)));

    final result = await repo.recordAdWatchedAndGrantSession();
    expect(result.match((f) => f.message, (_) => ''), contains('date or time'));
    expect(await adsToday(), 1);

    // Fixing the clock lifts the block.
    clock.setWall(clock.wallNow().add(const Duration(days: 1)));
    expect((await repo.recordAdWatchedAndGrantSession()).isRight(), isTrue);
  });

  test('after a reboot, winding the clock back cannot reset the counter', () async {
    for (var i = 0; i < FreeWifiRepository.maxAdsPerDay; i++) {
      await burnOneAd();
    }
    clock.reboot();
    clock.setWall(clock.wallNow().subtract(const Duration(days: 2)));
    expect(await adsToday(), 3);
    expect((await repo.recordAdWatchedAndGrantSession()).isLeft(), isTrue);
  });

  test('without a monotonic clock it still never lets time go backwards', () async {
    clock.monotonicAvailable = false;
    await burnOneAd();
    clock.setWall(clock.wallNow().subtract(const Duration(days: 1)));
    expect((await repo.recordAdWatchedAndGrantSession()).isLeft(), isTrue);
  });

  test('reset() drops the session but keeps the daily counter; a full reset clears both', () async {
    await repo.recordAdWatchedAndGrantSession();
    await repo.reset();
    expect((await repo.getActiveSession()).getOrElse((_) => null), isNull);
    expect(await adsToday(), 1);

    await repo.reset(includeDailyCounter: true);
    expect(store.snapshot, isEmpty);
    expect(await adsToday(), 0);
  });
}
