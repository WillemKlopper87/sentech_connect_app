import 'package:equatable/equatable.dart';

enum PassStatus { scheduled, active, expired, exhausted, revoked }

/// Where a pass came from. A newer server may add values: those read as [unknown].
enum PassSource { order, voucher, admin, unknown }

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
  );
}

/// A missing `source` (an older server) means an order's pass; an unrecognised one is [PassSource.unknown].
PassSource _sourceFromJson(Object? raw) {
  if (raw == null) return PassSource.order;
  return PassSource.values.where((s) => s.name == raw).firstOrNull ??
      PassSource.unknown;
}
