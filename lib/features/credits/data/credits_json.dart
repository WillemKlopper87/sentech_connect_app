import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credits_summary.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/mission.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/streak.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';

/// Decoders for the customer credits answers (`/v1/me/credits`, `/credits/ledger`,
/// `/streak`, `/streak/claim`, `/missions`, `/badges`). Enums (entry kind, mission
/// status, streak tier) map a value the app does not know to `unknown` instead of
/// failing the whole page: a newer server must not blank the wallet. The contract
/// test lists every current value, so a new platform value is still caught in CI.

Map<String, Object?> _map(Object? value) => Map<String, Object?>.from(value! as Map);

CreditTier creditTierFromApi(Object? value) => switch (value) {
  'none' => CreditTier.none,
  'silver' => CreditTier.silver,
  'gold' => CreditTier.gold,
  _ => CreditTier.unknown,
};

/// `CreditsOut.tier` is a free string in the schema (`none`, `silver`, `gold`);
/// an absent or unfamiliar value shows no tier rather than failing the wallet.
CreditTier? _lenientTier(Object? value) => switch (value) {
  'none' => CreditTier.none,
  'silver' => CreditTier.silver,
  'gold' => CreditTier.gold,
  _ => null,
};

CreditEntryKind creditEntryKindFromApi(Object? value) => switch (value) {
  'earn' => CreditEntryKind.earn,
  'spend' => CreditEntryKind.spend,
  'expire' => CreditEntryKind.expire,
  'clawback' => CreditEntryKind.clawback,
  'forfeit' => CreditEntryKind.forfeit,
  _ => CreditEntryKind.unknown,
};

MissionStatus missionStatusFromApi(Object? value) => switch (value) {
  'in_progress' => MissionStatus.inProgress,
  'ready' => MissionStatus.ready,
  'completed' => MissionStatus.completed,
  _ => MissionStatus.unknown,
};

CreditRates creditRatesFromJson(Map<String, Object?> json) => CreditRates(
  mbPerCredit: json['mb_per_credit']! as int,
  adCredits: json['ad_credits']! as int,
  packSizes: [for (final size in json['pack_sizes']! as List) size! as int],
  expiryDays: json['expiry_days']! as int,
);

CreditCaps creditCapsFromJson(Map<String, Object?> json) => CreditCaps(
  adToday: json['ad_today']! as int,
  adDailyMax: json['ad_daily_max']! as int,
  adMonth: json['ad_month']! as int,
  adMonthlyCap: json['ad_monthly_cap']! as int,
  overallMonth: json['overall_month']! as int,
  overallMonthlyCap: json['overall_monthly_cap']! as int,
);

/// `CreditsOut` -> [CreditsSummary].
CreditsSummary creditsSummaryFromJson(Map<String, Object?> json) => CreditsSummary(
  balance: json['balance']! as int,
  available: json['available']! as int,
  pending: json['pending']! as int,
  expiring30d: json['expiring_30d']! as int,
  frozen: json['frozen']! as bool,
  caps: creditCapsFromJson(_map(json['caps'])),
  rates: creditRatesFromJson(_map(json['rates'])),
  tier: _lenientTier(json['tier']),
  streak: json['streak'] as int?,
);

CreditEntry creditEntryFromJson(Map<String, Object?> json) => CreditEntry(
  id: json['id']! as int,
  kind: creditEntryKindFromApi(json['kind']),
  credits: json['credits']! as int,
  source: json['source']! as String,
  createdAt: DateTime.parse(json['created_at']! as String).toUtc(),
);

/// `CreditEntryPage` -> [LedgerPage].
LedgerPage ledgerPageFromJson(Map<String, Object?> json) => LedgerPage(
  items: [for (final item in json['items']! as List) creditEntryFromJson(_map(item))],
  nextCursor: json['next_cursor'] as String?,
);

StreakRules _streakRulesFromJson(Map<String, Object?> json) => StreakRules(
  dailyCredits: json['daily_credits']! as int,
  shortMilestoneDays: json['short_milestone_days']! as int,
  shortMilestoneBonus: json['short_milestone_bonus']! as int,
  longMilestoneDays: json['long_milestone_days']! as int,
  longMilestoneBonus: json['long_milestone_bonus']! as int,
  freezeCap: json['freeze_cap']! as int,
  silverStreakDays: json['silver_streak_days']! as int,
  goldStreakDays: json['gold_streak_days']! as int,
  silverPurchases: json['silver_purchases']! as int,
  goldPurchases: json['gold_purchases']! as int,
  tierWindowDays: json['tier_window_days']! as int,
);

/// `StreakOut` -> [StreakState]. `day` is validated as a calendar date and kept
/// as the server sent it.
StreakState streakStateFromJson(Map<String, Object?> json) {
  final day = json['day']! as String;
  parseApiDate(day);
  return StreakState(
    day: day,
    claimedToday: json['claimed_today']! as bool,
    runDays: json['run_days']! as int,
    bestRunDays: json['best_run_days']! as int,
    freezes: json['freezes']! as int,
    totalDays: json['total_days']! as int,
    tier: creditTierFromApi(json['tier']),
    nextMilestoneInDays: json['next_milestone_in_days']! as int,
    rules: _streakRulesFromJson(_map(json['rules'])),
  );
}

/// `StreakClaimOut` -> [ClaimResult].
ClaimResult claimResultFromJson(Map<String, Object?> json) => ClaimResult(
  claimed: json['claimed']! as bool,
  credits: json['credits']! as int,
  bonusCredits: json['bonus_credits']! as int,
  freezesUsed: json['freezes_used']! as int,
  milestones: [for (final days in json['milestones']! as List) days! as int],
  cappedBy: json['capped_by'] as String?,
  streak: streakStateFromJson(_map(json['streak'])),
);

DateTime? _optionalInstant(Object? value) => value == null ? null : DateTime.parse(value as String).toUtc();

/// `MissionOut` -> [Mission].
Mission missionFromJson(Map<String, Object?> json) => Mission(
  key: json['key']! as String,
  window: json['window']! as String,
  windowKey: json['window_key']! as String,
  target: json['target']! as int,
  progress: json['progress']! as int,
  rewardCredits: json['reward_credits']! as int,
  status: missionStatusFromApi(json['status']),
  completedAt: _optionalInstant(json['completed_at']),
);

/// `BadgeOut` -> [CreditBadge].
CreditBadge creditBadgeFromJson(Map<String, Object?> json) => CreditBadge(
  key: json['key']! as String,
  target: json['target']! as int,
  progress: json['progress']! as int,
  earned: json['earned']! as bool,
  awardedAt: _optionalInstant(json['awarded_at']),
);
