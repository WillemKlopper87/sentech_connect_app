import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';

/// Decoders for the 5G data usage answer (`/v1/me/subscriber/services/{id}/data`).
/// Closed enums (`plan_kind`, `state`) fail with [FormatException] on an unknown
/// value, which the client turns into a `ServerFailure`, instead of guessing.
/// The contract test lists every value so a new platform value is caught in CI.

FiveGPlanKind fiveGPlanKindFromApi(Object? value) => switch (value) {
  'capped' => FiveGPlanKind.capped,
  'fup' => FiveGPlanKind.fup,
  final other => throw FormatException('Unknown 5G plan kind $other'),
};

UsageState usageStateFromApi(Object? value) => switch (value) {
  'normal' => UsageState.normal,
  'slow_lane' => UsageState.slowLane,
  'cut_off' => UsageState.cutOff,
  'out_of_bundle' => UsageState.outOfBundle,
  'fup' => UsageState.fup,
  final other => throw FormatException('Unknown 5G usage state $other'),
};

/// `UnlockOfferOut` -> [UnlockOffer]. `bytes_mb` is megabytes (the name is the
/// platform's); money is integer cents, VAT included in the price.
UnlockOffer unlockOfferFromJson(Map<String, Object?> json) {
  return UnlockOffer(
    code: json['code']! as String,
    name: json['name']! as String,
    addedMb: json['bytes_mb']! as int,
    priceCents: json['price_cents']! as int,
    vatCents: json['vat_cents']! as int,
    validUntil: parseApiDate(json['valid_until']! as String),
  );
}

/// `FiveGDataOut` -> [FiveGUsage].
FiveGUsage fiveGUsageFromJson(Map<String, Object?> json) {
  final pending = json['pending_unlock'] == null ? null : Map<String, Object?>.from(json['pending_unlock']! as Map);
  final offers = json['offers'] as List? ?? const [];
  return FiveGUsage(
    planKind: fiveGPlanKindFromApi(json['plan_kind']),
    state: usageStateFromApi(json['state']),
    periodStart: parseApiDate(json['period_start']! as String),
    cycleEnd: parseApiDate(json['cycle_end']! as String),
    effectiveCapMb: json['effective_cap_mb'] as int?,
    countedUsageMb: json['counted_usage_mb'] as int?,
    usedPercent: json['used_percent'] as int?,
    rolloverMb: json['rollover_mb'] as int?,
    warnLevels: [for (final level in json['warn_levels'] as List? ?? const []) level! as int],
    nextWarnLevel: json['next_warn_level'] as int?,
    offers: [for (final offer in offers) unlockOfferFromJson(Map<String, Object?>.from(offer as Map))],
    pendingUnlock: pending == null
        ? null
        : PendingUnlock(orderId: pending['order_id']! as String, status: pending['status']! as String),
    restoring: json['restoring'] == true,
  );
}
