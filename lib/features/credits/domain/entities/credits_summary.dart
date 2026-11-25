import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/credits/domain/entities/tier.dart';

/// The provider's public rates (`RatesOut`). Nothing in the app hard-codes
/// them: the pack sizes, the data per credit and the expiry all come from here.
class CreditRates extends Equatable {
  const CreditRates({
    required this.mbPerCredit,
    required this.adCredits,
    required this.packSizes,
    required this.expiryDays,
  });

  final int mbPerCredit;

  /// Credits one rewarded ad would pay. Ads are not part of this release; the
  /// value is read so a later release needs no contract change.
  final int adCredits;
  final List<int> packSizes;
  final int expiryDays;

  /// Megabytes a pack of [credits] gives (`credits * mbPerCredit`).
  int megabytesFor(int credits) => credits * mbPerCredit;

  @override
  List<Object?> get props => [mbPerCredit, adCredits, packSizes, expiryDays];
}

/// Earn caps as the server counted them (`CapsOut`). The app only shows them.
class CreditCaps extends Equatable {
  const CreditCaps({
    required this.adToday,
    required this.adDailyMax,
    required this.adMonth,
    required this.adMonthlyCap,
    required this.overallMonth,
    required this.overallMonthlyCap,
  });

  final int adToday;
  final int adDailyMax;
  final int adMonth;
  final int adMonthlyCap;
  final int overallMonth;
  final int overallMonthlyCap;

  /// True when the server's own count for the month has reached its own monthly
  /// limit: new earnings are held back until next month. Both numbers come from
  /// the server; nothing is estimated.
  bool get monthlyEarnLimitReached => overallMonthlyCap > 0 && overallMonth >= overallMonthlyCap;

  @override
  List<Object?> get props => [adToday, adDailyMax, adMonth, adMonthlyCap, overallMonth, overallMonthlyCap];
}

/// `CreditsOut`: the wallet as the server reports it right now.
class CreditsSummary extends Equatable {
  const CreditsSummary({
    required this.balance,
    required this.available,
    required this.pending,
    required this.expiring30d,
    required this.frozen,
    required this.caps,
    required this.rates,
    this.tier,
    this.streak,
  });

  /// Credits held: available plus pending.
  final int balance;

  /// What a redemption can use right now.
  final int available;

  /// Held back for a hold window and not yet spendable.
  final int pending;

  /// Credits that expire within 30 days (the server's number).
  final int expiring30d;
  final bool frozen;
  final CreditCaps caps;
  final CreditRates rates;
  final CreditTier? tier;
  final int? streak;

  @override
  List<Object?> get props => [balance, available, pending, expiring30d, frozen, caps, rates, tier, streak];
}
