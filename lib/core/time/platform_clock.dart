import 'package:flutter/services.dart';

/// Wall clock plus a boot-relative monotonic clock.
///
/// The wall clock can be changed by the user; Android's
/// `SystemClock.elapsedRealtime()` (milliseconds since boot, including deep
/// sleep) cannot. Free-WiFi accounting uses both so that moving the clock
/// does not stretch a session or reset the daily cap — see
/// `MockFreeWifiRepository`. This is still only a client-side deterrent; real
/// enforcement needs server time (see `FreeWifiRepository`).
abstract class PlatformClock {
  DateTime wallNow();

  /// Milliseconds since device boot, or null where the platform provides no
  /// such clock (tests, web, iOS until implemented).
  Future<int?> elapsedRealtimeMs();
}

class SystemPlatformClock implements PlatformClock {
  static const _channel = MethodChannel('za.co.sentech.sentech_connect_app/platform');

  @override
  DateTime wallNow() => DateTime.now();

  @override
  Future<int?> elapsedRealtimeMs() async {
    try {
      return await _channel.invokeMethod<int>('elapsedRealtimeMs');
    } on MissingPluginException {
      return null;
    } on PlatformException {
      return null;
    }
  }
}

/// Fully scriptable clock for tests: advance time, jump the wall clock, or
/// simulate a reboot.
class FakePlatformClock implements PlatformClock {
  FakePlatformClock({DateTime? start, int bootElapsedMs = 1000000})
      : _wall = start ?? DateTime(2026, 9, 30, 12),
        _elapsed = bootElapsedMs;

  DateTime _wall;
  int _elapsed;

  /// When false, behaves like a platform without a monotonic clock.
  bool monotonicAvailable = true;

  /// Normal passage of time: both clocks advance.
  void advance(Duration d) {
    _wall = _wall.add(d);
    _elapsed += d.inMilliseconds;
  }

  /// The user changes the wall clock; the monotonic clock is unaffected.
  void setWall(DateTime value) => _wall = value;

  /// Reboot: the monotonic clock restarts from near zero.
  void reboot() => _elapsed = 1000;

  @override
  DateTime wallNow() => _wall;

  @override
  Future<int?> elapsedRealtimeMs() async => monotonicAvailable ? _elapsed : null;
}
