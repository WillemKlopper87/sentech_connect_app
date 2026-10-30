import 'package:equatable/equatable.dart';

/// `PublicPlanOut.kind`.
enum SubscriberPlanKind { recurringHotspot, fixedWireless }

/// A monthly plan a customer can sign up for (`GET /v1/subscriber-plans`).
/// Prices are integer cents in ZAR; whether they include VAT is not stated by
/// the API (plan doc question Q9).
class SubscriberPlan extends Equatable {
  const SubscriberPlan({
    required this.id,
    required this.code,
    required this.name,
    required this.description,
    required this.kind,
    required this.kycRequired,
    required this.priceCents,
    required this.setupFeeCents,
    required this.downKbps,
    required this.upKbps,
    required this.maxDevices,
    required this.fupAction,
    this.burstDownKbps,
    this.burstUpKbps,
    this.burstSeconds,
    this.fupBytes,
    this.fupDownKbps,
    this.fupUpKbps,
  });

  final String id;
  final String code;
  final String name;
  final String description;
  final SubscriberPlanKind kind;
  final bool kycRequired;
  final int priceCents;
  final int setupFeeCents;
  final int downKbps;
  final int upKbps;
  final int maxDevices;
  final String fupAction;
  final int? burstDownKbps;
  final int? burstUpKbps;
  final int? burstSeconds;
  final int? fupBytes;
  final int? fupDownKbps;
  final int? fupUpKbps;

  @override
  List<Object?> get props => [
    id, code, name, description, kind, kycRequired, priceCents, setupFeeCents,
    downKbps, upKbps, maxDevices, fupAction, burstDownKbps, burstUpKbps,
    burstSeconds, fupBytes, fupDownKbps, fupUpKbps,
  ];
}
