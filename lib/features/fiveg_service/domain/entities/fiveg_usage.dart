import 'package:equatable/equatable.dart';

/// `plan_kind` of the data usage answer. A capped plan has an allowance, a
/// slow lane and paid unlocks; a fair-use (uncapped) plan never does.
enum FiveGPlanKind { capped, fup }

/// `state` of the data usage answer: what the customer's speed is doing now.
enum UsageState { normal, slowLane, cutOff, outOfBundle, fup }

/// The warning band a usage percentage falls in. [none] is below 50%.
enum UsageWarning { none, p50, p80, p100 }

/// A paid unlock the customer can buy for this month (`offers[]`).
class UnlockOffer extends Equatable {
  const UnlockOffer({
    required this.code,
    required this.name,
    required this.addedMb,
    required this.priceCents,
    required this.vatCents,
    required this.validUntil,
  });

  /// The `product_code` sent back when the unlock is bought.
  final String code;
  final String name;

  /// Data added by the unlock, in megabytes (the wire field is `bytes_mb`).
  final int addedMb;

  /// Price including VAT, in integer cents.
  final int priceCents;
  final int vatCents;

  /// The last day the unlock counts (a plain calendar date).
  final DateTime validUntil;

  @override
  List<Object?> get props => [code, name, addedMb, priceCents, vatCents, validUntil];
}

/// An unlock order that was created but not yet paid (`pending_unlock`).
class PendingUnlock extends Equatable {
  const PendingUnlock({required this.orderId, required this.status});

  final String orderId;
  final String status;

  @override
  List<Object?> get props => [orderId, status];
}

/// The customer's data allowance on one service for the current calendar
/// month (`GET .../data`). Usage figures are megabytes; the dates are plain
/// calendar dates in South Africa time.
///
/// [cycleEnd] is the last day of the cycle. The allowance resets the day
/// after it (see `resetDayFor`).
class FiveGUsage extends Equatable {
  const FiveGUsage({
    required this.planKind,
    required this.state,
    required this.periodStart,
    required this.cycleEnd,
    required this.restoring,
    this.effectiveCapMb,
    this.countedUsageMb,
    this.usedPercent,
    this.rolloverMb,
    this.warnLevels = const [],
    this.nextWarnLevel,
    this.offers = const [],
    this.pendingUnlock,
  });

  final FiveGPlanKind planKind;
  final UsageState state;
  final DateTime periodStart;
  final DateTime cycleEnd;

  /// The allowance for the month including rollover and unlocks (null on fair use).
  final int? effectiveCapMb;
  final int? countedUsageMb;

  /// 0 to 100; null on fair use.
  final int? usedPercent;

  /// Unused data carried in from last month (capped plans only).
  final int? rolloverMb;
  final List<int> warnLevels;
  final int? nextWarnLevel;
  final List<UnlockOffer> offers;
  final PendingUnlock? pendingUnlock;

  /// True while a paid unlock is being applied (the service is restored by a
  /// background job shortly after payment).
  final bool restoring;

  bool get isCapped => planKind == FiveGPlanKind.capped;

  @override
  List<Object?> get props => [
    planKind,
    state,
    periodStart,
    cycleEnd,
    effectiveCapMb,
    countedUsageMb,
    usedPercent,
    rolloverMb,
    warnLevels,
    nextWarnLevel,
    offers,
    pendingUnlock,
    restoring,
  ];
}
