import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';

/// `StreakRulesOut`: the provider's public check-in rules.
class StreakRules extends Equatable {
  const StreakRules({
    required this.dailyCredits,
    required this.shortMilestoneDays,
    required this.shortMilestoneBonus,
    required this.longMilestoneDays,
    required this.longMilestoneBonus,
    required this.freezeCap,
    required this.silverStreakDays,
    required this.goldStreakDays,
    required this.silverPurchases,
    required this.goldPurchases,
    required this.tierWindowDays,
  });

  final int dailyCredits;
  final int shortMilestoneDays;
  final int shortMilestoneBonus;
  final int longMilestoneDays;
  final int longMilestoneBonus;
  final int freezeCap;
  final int silverStreakDays;
  final int goldStreakDays;
  final int silverPurchases;
  final int goldPurchases;
  final int tierWindowDays;

  @override
  List<Object?> get props => [
    dailyCredits,
    shortMilestoneDays,
    shortMilestoneBonus,
    longMilestoneDays,
    longMilestoneBonus,
    freezeCap,
    silverStreakDays,
    goldStreakDays,
    silverPurchases,
    goldPurchases,
    tierWindowDays,
  ];
}

/// `StreakOut`. [day] is today's date in Africa/Johannesburg, decided by the
/// server: the phone's own date and time zone never decide what counts as a day.
class StreakState extends Equatable {
  const StreakState({
    required this.day,
    required this.claimedToday,
    required this.runDays,
    required this.bestRunDays,
    required this.freezes,
    required this.totalDays,
    required this.tier,
    required this.nextMilestoneInDays,
    required this.rules,
  });

  /// A plain calendar date, `YYYY-MM-DD`, kept as the server sent it.
  final String day;
  final bool claimedToday;
  final int runDays;
  final int bestRunDays;
  final int freezes;
  final int totalDays;
  final CreditTier tier;
  final int nextMilestoneInDays;
  final StreakRules rules;

  @override
  List<Object?> get props => [
    day,
    claimedToday,
    runDays,
    bestRunDays,
    freezes,
    totalDays,
    tier,
    nextMilestoneInDays,
    rules,
  ];
}

/// `StreakClaimOut`: what a check-in did. [claimed] is false when today had
/// already been claimed (the answer then repeats what the first claim paid).
class ClaimResult extends Equatable {
  const ClaimResult({
    required this.claimed,
    required this.credits,
    required this.bonusCredits,
    required this.freezesUsed,
    required this.milestones,
    required this.streak,
    this.cappedBy,
  });

  final bool claimed;
  final int credits;
  final int bonusCredits;
  final int freezesUsed;
  final List<int> milestones;

  /// The earn limit that held credits back, as the server names it; null when
  /// nothing was held back.
  final String? cappedBy;
  final StreakState streak;

  @override
  List<Object?> get props => [claimed, credits, bonusCredits, freezesUsed, milestones, cappedBy, streak];
}
