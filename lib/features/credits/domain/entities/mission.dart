import 'package:equatable/equatable.dart';

/// `MissionOut.status`.
enum MissionStatus { inProgress, ready, completed }

/// One mission as the server evaluated it. [progress] is the server's count:
/// the app never works it out.
class Mission extends Equatable {
  const Mission({
    required this.key,
    required this.window,
    required this.windowKey,
    required this.target,
    required this.progress,
    required this.rewardCredits,
    required this.status,
    this.completedAt,
  });

  final String key;

  /// `once` or `monthly` (Johannesburg calendar month).
  final String window;
  final String windowKey;
  final int target;
  final int progress;
  final int rewardCredits;
  final MissionStatus status;
  final DateTime? completedAt;

  @override
  List<Object?> get props => [key, window, windowKey, target, progress, rewardCredits, status, completedAt];
}

/// `BadgeOut`.
class CreditBadge extends Equatable {
  const CreditBadge({
    required this.key,
    required this.target,
    required this.progress,
    required this.earned,
    this.awardedAt,
  });

  final String key;
  final int target;
  final int progress;
  final bool earned;
  final DateTime? awardedAt;

  @override
  List<Object?> get props => [key, target, progress, earned, awardedAt];
}
