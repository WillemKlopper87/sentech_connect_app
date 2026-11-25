import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/credit_entry.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';

/// Names for the server's mission and badge keys. The server sends no titles,
/// so an unfamiliar key gets a neutral name instead of its raw key.
String missionName(AppLocalizations l10n, String key) => switch (key) {
  'first_checkin' => l10n.creditsMissionFirstCheckin,
  'profile_complete' => l10n.creditsMissionProfileComplete,
  'first_purchase' => l10n.creditsMissionFirstPurchase,
  'first_voucher' => l10n.creditsMissionFirstVoucher,
  'first_redemption' => l10n.creditsMissionFirstRedemption,
  'checkins_20' => l10n.creditsMissionMonthlyCheckins,
  'purchases_3_month' => l10n.creditsMissionMonthlyPurchases,
  _ => l10n.creditsMissionUnknown,
};

String badgeName(AppLocalizations l10n, String key) => switch (key) {
  'first_checkin' => l10n.creditsBadgeFirstCheckin,
  'streak_7' => l10n.creditsBadgeStreak7,
  'streak_30' => l10n.creditsBadgeStreak30,
  'streak_100' => l10n.creditsBadgeStreak100,
  'missions_3' => l10n.creditsBadgeMissions3,
  'missions_10' => l10n.creditsBadgeMissions10,
  'first_redemption' => l10n.creditsBadgeFirstRedemption,
  'tier_silver' => l10n.creditsBadgeTierSilver,
  'tier_gold' => l10n.creditsBadgeTierGold,
  _ => l10n.creditsBadgeUnknown,
};

/// The name of a tier worth showing; none (and no tier at all) shows nothing.
String? tierName(AppLocalizations l10n, CreditTier? tier) => switch (tier) {
  CreditTier.silver => l10n.creditsTierSilver,
  CreditTier.gold => l10n.creditsTierGold,
  _ => null,
};

String entryKindText(AppLocalizations l10n, CreditEntryKind kind) => switch (kind) {
  CreditEntryKind.earn => l10n.creditsEntryEarn,
  CreditEntryKind.spend => l10n.creditsEntrySpend,
  CreditEntryKind.expire => l10n.creditsEntryExpire,
  CreditEntryKind.clawback => l10n.creditsEntryClawback,
  CreditEntryKind.forfeit => l10n.creditsEntryForfeit,
};

/// A history line's title: the source when the app knows it, else the kind.
String entryTitle(AppLocalizations l10n, CreditEntry entry) => switch (entry.source) {
  'streak' => l10n.creditsSourceStreak,
  'streak_bonus' => l10n.creditsSourceStreakBonus,
  'mission' => l10n.creditsSourceMission,
  'pack_redemption' => l10n.creditsSourcePack,
  'admin' => l10n.creditsSourceAdmin,
  _ => entryKindText(l10n, entry.kind),
};

/// The sentence for a check-in that paid nothing because of an earning limit.
String cappedSentence(AppLocalizations l10n, String cappedBy) => switch (cappedBy) {
  'overall_monthly' => l10n.creditsCheckInCappedMonthly,
  'mission_monthly' => l10n.creditsCheckInCappedMission,
  _ => l10n.creditsCheckInCappedOther,
};

/// The plain-words explanation for a refusal that blocks every action on a
/// Rewards page until something outside the app changes (a frozen wallet, an
/// inactive account, a pause, or the feature being off); null for any other
/// failure.
String? blockingNoticeText(AppLocalizations l10n, Object? failure) => switch (failure) {
  WalletFrozenFailure() => l10n.creditsFrozenNotice,
  CustomerInactiveFailure() => l10n.creditsInactiveNotice,
  CreditsPausedFailure() => l10n.creditsPausedNotice,
  CreditsNotAvailableFailure() => l10n.creditsUnavailable,
  _ => null,
};
