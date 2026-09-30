import 'package:equatable/equatable.dart';

/// A temporary free-WiFi grant, earned by watching an ad. Data usage
/// within the session is a mock proxy for what a real integration would
/// pull from Sentech's BSS in near-real-time — there's no live network
/// session to measure here, so remaining data is estimated from elapsed
/// time against the allowance rather than actually metered.
///
/// Elapsed time is NOT computed from `DateTime.now()`: the repository works
/// out how much of the session has already elapsed using its tamper-aware
/// clock ([elapsedAtLoad]) and the session then counts on from there with a
/// monotonic [Stopwatch], so changing the phone's clock while the screen is
/// open has no effect.
class FreeWifiSession extends Equatable {
  FreeWifiSession({
    required this.grantedAt,
    required this.durationMinutes,
    required this.dataAllowanceMb,
    this.elapsedAtLoad = Duration.zero,
  }) : _sinceLoad = Stopwatch()..start();

  final DateTime grantedAt;
  final int durationMinutes;
  final int dataAllowanceMb;
  final Duration elapsedAtLoad;
  final Stopwatch _sinceLoad;

  Duration get total => Duration(minutes: durationMinutes);

  Duration get elapsed => elapsedAtLoad + _sinceLoad.elapsed;

  Duration get remaining {
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get isExpired => remaining == Duration.zero;

  double get elapsedFraction => (elapsed.inSeconds / total.inSeconds).clamp(0, 1).toDouble();

  double get dataUsedMb => dataAllowanceMb * elapsedFraction;

  double get dataRemainingMb => dataAllowanceMb - dataUsedMb;

  @override
  List<Object?> get props => [grantedAt, durationMinutes, dataAllowanceMb];
}
