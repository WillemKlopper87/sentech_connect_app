import 'package:equatable/equatable.dart';

/// A temporary free-WiFi grant, earned by watching an ad. Data usage
/// within the session is a mock proxy for what a real integration would
/// pull from Sentech's BSS in near-real-time — there's no live network
/// session to measure here, so remaining data is estimated from elapsed
/// time against the allowance rather than actually metered.
class FreeWifiSession extends Equatable {
  const FreeWifiSession({
    required this.grantedAt,
    required this.durationMinutes,
    required this.dataAllowanceMb,
  });

  final DateTime grantedAt;
  final int durationMinutes;
  final int dataAllowanceMb;

  Duration get elapsed => DateTime.now().difference(grantedAt);

  Duration get remaining {
    final total = Duration(minutes: durationMinutes);
    final left = total - elapsed;
    return left.isNegative ? Duration.zero : left;
  }

  bool get isExpired => remaining == Duration.zero;

  double get elapsedFraction =>
      (elapsed.inSeconds / Duration(minutes: durationMinutes).inSeconds).clamp(0, 1);

  double get dataUsedMb => dataAllowanceMb * elapsedFraction;

  double get dataRemainingMb => dataAllowanceMb - dataUsedMb;

  @override
  List<Object?> get props => [grantedAt, durationMinutes, dataAllowanceMb];
}
