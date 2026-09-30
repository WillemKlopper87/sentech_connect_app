import 'dart:convert';
import 'dart:math' as math;

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/storage/secure_store.dart';
import 'package:sentech_connect_app/core/time/platform_clock.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/free_wifi_session.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/repositories/free_wifi_repository.dart';

/// On-device stand-in for the server entitlement API (see the note on
/// [FreeWifiRepository]: this can only ever be a deterrent).
///
/// What it does to make casual cheating harder:
///  * keeps a trusted timeline: a persisted anchor (wall time + boot-relative
///    monotonic time). While the device has not rebooted, "now" is the anchor
///    plus elapsed monotonic time, so moving the wall clock forward or back
///    neither extends a session nor rolls the daily counter over. After a
///    reboot (monotonic clock restarts) time can only move forward from the
///    last anchor.
///  * detects the wall clock moved backwards and refuses to grant a session
///    until it is corrected.
///  * checks the daily cap BEFORE incrementing, so a rejected request never
///    changes the counter.
///  * stores state in the Keystore-backed [SecureStore] rather than plain prefs.
/// It does nothing about clearing app data or reinstalling.
class MockFreeWifiRepository implements FreeWifiRepository {
  MockFreeWifiRepository(this._store, {PlatformClock? clock}) : _clock = clock ?? SystemPlatformClock();

  static const _stateKey = 'free_wifi_state';

  /// Wall-clock differences smaller than this are treated as normal drift /
  /// NTP corrections, not tampering.
  static const clockTolerance = Duration(minutes: 2);

  static const _sessionMinutes = 45;
  static const _dataAllowanceMb = 500;

  final SecureStore _store;
  final PlatformClock _clock;

  @override
  Future<Either<Failure, int>> getAdsWatchedToday() async {
    final (state, _) = await _synced();
    return Right(state.adCount);
  }

  @override
  Future<Either<Failure, FreeWifiSession?>> getActiveSession() async {
    final (state, now) = await _synced();
    final session = _activeSession(state, now.trusted);
    if (session == null && state.grantedAtMs != null) {
      state.clearSession(); // expired
      await _save(state);
    }
    return Right(session);
  }

  @override
  Future<Either<Failure, FreeWifiSession>> recordAdWatchedAndGrantSession() async {
    final (state, now) = await _synced();

    if (now.clockMovedBack) {
      return const Left(ValidationFailure(
        "Your phone's date or time looks wrong. Set it to automatic and try again.",
      ));
    }
    if (_activeSession(state, now.trusted) != null) {
      return const Left(ValidationFailure('You already have a free WiFi session running.'));
    }
    // Limit check first, so a rejected request never mutates the counter.
    if (state.adCount >= FreeWifiRepository.maxAdsPerDay) {
      return const Left(ValidationFailure("You've reached today's free WiFi limit."));
    }

    state.adCount += 1;
    state.grantedAtMs = now.trusted.millisecondsSinceEpoch;
    state.durationMin = _sessionMinutes;
    await _save(state);
    return Right(FreeWifiSession(
      grantedAt: now.trusted,
      durationMinutes: _sessionMinutes,
      dataAllowanceMb: _dataAllowanceMb,
    ));
  }

  @override
  Future<void> reset({bool includeDailyCounter = false}) async {
    if (includeDailyCounter) {
      await _store.delete(_stateKey);
      return;
    }
    final (state, _) = await _synced();
    state.clearSession();
    await _save(state);
  }

  FreeWifiSession? _activeSession(_State state, DateTime trustedNow) {
    final grantedMs = state.grantedAtMs;
    final minutes = state.durationMin;
    if (grantedMs == null || minutes == null) return null;
    final elapsed = Duration(milliseconds: trustedNow.millisecondsSinceEpoch - grantedMs);
    if (elapsed >= Duration(minutes: minutes)) return null;
    return FreeWifiSession(
      grantedAt: DateTime.fromMillisecondsSinceEpoch(grantedMs),
      durationMinutes: minutes,
      dataAllowanceMb: _dataAllowanceMb,
      elapsedAtLoad: elapsed.isNegative ? Duration.zero : elapsed,
    );
  }

  /// Loads persisted state and advances the trusted timeline to "now",
  /// rolling the daily counter over when the trusted date changes.
  Future<(_State, _TrustedNow)> _synced() async {
    final state = await _load();
    final wall = _clock.wallNow();
    final elapsed = await _clock.elapsedRealtimeMs();

    final anchorWall = state.anchorWallMs;
    final anchorElapsed = state.anchorElapsedMs;
    final int trustedMs;
    if (anchorWall == null) {
      trustedMs = wall.millisecondsSinceEpoch;
    } else if (elapsed != null && anchorElapsed != null && elapsed >= anchorElapsed) {
      trustedMs = anchorWall + (elapsed - anchorElapsed); // same boot
    } else {
      // Rebooted (or no monotonic clock): time may only move forward.
      trustedMs = math.max(wall.millisecondsSinceEpoch, anchorWall);
    }
    final movedBack = wall.millisecondsSinceEpoch < trustedMs - clockTolerance.inMilliseconds;

    state.anchorWallMs = trustedMs;
    state.anchorElapsedMs = elapsed;
    final trusted = DateTime.fromMillisecondsSinceEpoch(trustedMs);
    final today = _dayKey(trusted);
    if (state.dayKey != today) {
      state.dayKey = today;
      state.adCount = 0;
    }
    await _save(state); // persist the refreshed anchor / day rollover
    return (state, _TrustedNow(trusted, movedBack));
  }

  Future<_State> _load() async {
    final raw = await _store.read(_stateKey);
    if (raw == null) return _State();
    try {
      return _State.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return _State();
    }
  }

  Future<void> _save(_State state) => _store.write(_stateKey, jsonEncode(state.toJson()));

  static String _dayKey(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

class _TrustedNow {
  const _TrustedNow(this.trusted, this.clockMovedBack);

  final DateTime trusted;
  final bool clockMovedBack;
}

class _State {
  _State({
    this.anchorWallMs,
    this.anchorElapsedMs,
    this.dayKey,
    this.adCount = 0,
    this.grantedAtMs,
    this.durationMin,
  });

  int? anchorWallMs;
  int? anchorElapsedMs;
  String? dayKey;
  int adCount;
  int? grantedAtMs;
  int? durationMin;

  void clearSession() {
    grantedAtMs = null;
    durationMin = null;
  }

  Map<String, dynamic> toJson() => {
        'anchorWallMs': anchorWallMs,
        'anchorElapsedMs': anchorElapsedMs,
        'dayKey': dayKey,
        'adCount': adCount,
        'grantedAtMs': grantedAtMs,
        'durationMin': durationMin,
      };

  factory _State.fromJson(Map<String, dynamic> json) => _State(
        anchorWallMs: json['anchorWallMs'] as int?,
        anchorElapsedMs: json['anchorElapsedMs'] as int?,
        dayKey: json['dayKey'] as String?,
        adCount: json['adCount'] as int? ?? 0,
        grantedAtMs: json['grantedAtMs'] as int?,
        durationMin: json['durationMin'] as int?,
      );
}
