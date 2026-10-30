import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

/// A service with sensible defaults; override what a test is about.
SubscriberService testService({
  String id = 'svc-1',
  String planName = 'Home Hotspot 10',
  SubscriberPlanKind kind = SubscriberPlanKind.recurringHotspot,
  ServiceStatus status = ServiceStatus.active,
  SuspendReason? suspendReason,
  ActivationBlocker? activationBlocker,
  DateTime? paidThrough,
  DateTime? cancelEffectiveOn,
  DateTime? cancelledAt,
  String? pendingPlanId,
  String? pendingPlanName,
  DateTime? planChangeOn,
  int priceCents = 19900,
}) => SubscriberService(
  id: id,
  accountId: 'acc-1',
  serviceNo: 'SV-000101',
  status: status,
  suspendReason: suspendReason,
  activationBlocker: activationBlocker,
  planId: 'plan-1',
  planName: planName,
  kind: kind,
  priceCents: priceCents,
  downKbps: 10000,
  upKbps: 5000,
  paidThrough: paidThrough,
  createdAt: DateTime.utc(2026, 9, 1),
  cancelledAt: cancelledAt,
  cancelEffectiveOn: cancelEffectiveOn,
  pendingPlanId: pendingPlanId,
  pendingPlanName: pendingPlanName,
  planChangeOn: planChangeOn,
);
