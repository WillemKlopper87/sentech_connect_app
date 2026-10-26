import 'package:equatable/equatable.dart';

/// `suspended`: the provider paused the service (for example an unpaid
/// invoice); it can come back, so it is neither expired nor revoked.
enum PassStatus { scheduled, active, suspended, expired, exhausted, revoked }

/// Where a pass came from. A newer server may add values: those read as [unknown].
enum PassSource { order, voucher, admin, service, unknown }

/// Why a pass exists (`origin_type`). A newer server may add values: those
/// read as [unknown]. Nothing here is displayed yet (display waits for WP-30).
enum PassOrigin {
  order('order'),
  voucher('voucher'),
  admin('admin'),
  service('service'),
  freeTime('free_time'),
  credits('credits'),
  sponsored('sponsored'),
  roaming('roaming'),
  unknown('unknown');

  const PassOrigin(this.apiName);
  final String apiName;

  static PassOrigin fromApi(Object? raw) =>
      PassOrigin.values.where((o) => o.apiName == raw).firstOrNull ??
      PassOrigin.unknown;
}

/// What a pass is limited to (`scope[].kind`). Kind names only: the API never
/// sends which site, zone or provider.
enum PassScopeKind {
  site('site'),
  zone('zone'),
  tenant('tenant'),
  timeWindow('time_window'),
  nasClass('nas_class'),
  unknown('unknown');

  const PassScopeKind(this.apiName);
  final String apiName;

  static PassScopeKind fromApi(String raw) =>
      PassScopeKind.values.where((k) => k.apiName == raw).firstOrNull ??
      PassScopeKind.unknown;
}

class PassScope extends Equatable {
  const PassScope(this.kind);
  final PassScopeKind kind;

  @override
  List<Object?> get props => [kind];
}

/// A hotspot entitlement bought with a pass (`GET /v1/me/entitlements`).
/// The server owns time, usage and status (spec §2).
class Pass extends Equatable {
  const Pass({
    required this.id,
    this.orderId,
    this.source = PassSource.order,
    required this.productName,
    required this.status,
    required this.startsAt,
    required this.expiresAt,
    required this.durationMinutes,
    this.dataMb,
    this.speedKbps,
    required this.maxDevices,
    this.usedBytes = 0,
    this.origin = PassOrigin.order,
    this.scopes = const [],
    this.fundedByOther = false,
    this.homeServingDiffers = false,
  });

  final String id;

  /// Null for a pass that no order paid for (a redeemed voucher, an admin grant).
  final String? orderId;
  final PassSource source;
  final String productName;
  final PassStatus status;
  final DateTime startsAt;
  final DateTime expiresAt;
  final int durationMinutes;
  final int? dataMb;
  final int? speedKbps;
  final int maxDevices;
  final int usedBytes;

  /// Why the pass exists. Not displayed in this slice.
  final PassOrigin origin;

  /// Kinds of limit on the pass; empty means none reported.
  final List<PassScope> scopes;

  /// Someone other than the customer paid. The payer's name is never sent.
  final bool fundedByOther;

  /// The pass is served by a different provider than its home provider.
  final bool homeServingDiffers;

  bool get isCurrent =>
      status == PassStatus.active || status == PassStatus.scheduled;

  /// 0..1 of the data cap used, or null for uncapped passes.
  double? get dataUsedFraction {
    final cap = dataMb;
    if (cap == null || cap == 0) return null;
    return (usedBytes / (cap * 1024 * 1024)).clamp(0, 1).toDouble();
  }

  @override
  List<Object?> get props => [
    id,
    orderId,
    source,
    productName,
    status,
    startsAt,
    expiresAt,
    durationMinutes,
    dataMb,
    speedKbps,
    maxDevices,
    usedBytes,
    origin,
    scopes,
    fundedByOther,
    homeServingDiffers,
  ];
}

/// M1 `EntitlementOut` -> [Pass].
Pass passFromJson(Map<String, Object?> json) {
  final status = PassStatus.values
      .where((s) => s.name == json['status'])
      .firstOrNull;
  if (status == null) {
    throw FormatException('Unknown entitlement status ${json['status']}');
  }
  return Pass(
    id: json['id']! as String,
    orderId: json['order_id'] as String?,
    source: _sourceFromJson(json['source']),
    productName: json['product_name']! as String,
    status: status,
    startsAt: DateTime.parse(json['starts_at']! as String).toUtc(),
    expiresAt: DateTime.parse(json['expires_at']! as String).toUtc(),
    durationMinutes: json['duration_minutes']! as int,
    dataMb: json['data_mb'] as int?,
    speedKbps: json['speed_kbps'] as int?,
    maxDevices: json['max_devices']! as int,
    usedBytes: json['used_bytes'] as int? ?? 0,
    origin: _originFromJson(json),
    scopes: _scopesFromJson(json['scope']),
    fundedByOther: json['funded_by_other'] == true,
    homeServingDiffers: json['home_serving_differs'] == true,
  );
}

/// `origin_type` when the server sends it, else the older `source`.
PassOrigin _originFromJson(Map<String, Object?> json) {
  if (json['origin_type'] != null) {
    return PassOrigin.fromApi(json['origin_type']);
  }
  return switch (_sourceFromJson(json['source'])) {
    PassSource.order => PassOrigin.order,
    PassSource.voucher => PassOrigin.voucher,
    PassSource.admin => PassOrigin.admin,
    PassSource.service => PassOrigin.service,
    PassSource.unknown => PassOrigin.unknown,
  };
}

/// Items that are not an object with a string `kind` are dropped; an unrecognised kind is kept as unknown.
List<PassScope> _scopesFromJson(Object? raw) => raw is List
    ? List.unmodifiable([
        for (final item in raw)
          if (item is Map && item['kind'] is String)
            PassScope(PassScopeKind.fromApi(item['kind']! as String)),
      ])
    : const [];

/// A missing `source` (an older server) means an order's pass; an unrecognised one is [PassSource.unknown].
PassSource _sourceFromJson(Object? raw) {
  if (raw == null) return PassSource.order;
  return PassSource.values.where((s) => s.name == raw).firstOrNull ??
      PassSource.unknown;
}
