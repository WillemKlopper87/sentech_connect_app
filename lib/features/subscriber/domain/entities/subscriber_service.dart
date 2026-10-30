import 'package:equatable/equatable.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';

/// `CustomerServiceOut.status`, the platform's `subscriber_service` states.
enum ServiceStatus { pending, active, suspended, cancelled }

/// `CustomerServiceOut.suspend_reason`.
enum SuspendReason { nonPayment, customerRequest, admin, kyc }

/// `CustomerServiceOut.activation_blocker`: the first gate that still keeps a
/// `pending` service from starting. A null blocker on a pending service means
/// nothing the customer can act on is left (activation is automatic after
/// payment, or waits on the provider's staff): show generic pending copy.
/// [unknown] is a value this app version does not know; treat it like null.
enum ActivationBlocker {
  firstInvoiceUnpaid,
  customerLinkRequired,
  serviceContractRequired,
  kycRequired,
  awaitingInstallation,
  unknown,
}

/// One service on the customer's account (`CustomerServiceOut`). Plan facts
/// ([planName], [kind], [priceCents], speeds) are those of the plan version
/// the service is on, resolved by the platform even when the plan is retired.
/// Fields named `*On` and `*Through` are plain calendar dates (see
/// `parseApiDate`); `*At` are instants in UTC.
class SubscriberService extends Equatable {
  const SubscriberService({
    required this.id,
    required this.accountId,
    required this.serviceNo,
    required this.status,
    required this.planId,
    required this.planName,
    required this.kind,
    required this.priceCents,
    required this.downKbps,
    required this.upKbps,
    required this.createdAt,
    this.suspendReason,
    this.activationBlocker,
    this.billedThrough,
    this.paidThrough,
    this.activatedAt,
    this.suspendedAt,
    this.cancelledAt,
    this.cancelEffectiveOn,
    this.pendingPlanId,
    this.pendingPlanName,
    this.planChangeOn,
  });

  final String id;
  final String accountId;
  final String serviceNo;
  final ServiceStatus status;
  final SuspendReason? suspendReason;

  /// Only ever set on a [ServiceStatus.pending] service.
  final ActivationBlocker? activationBlocker;
  final String planId;
  final String planName;
  final SubscriberPlanKind kind;
  final int priceCents;
  final int downKbps;
  final int upKbps;
  final DateTime? billedThrough;
  final DateTime? paidThrough;
  final DateTime createdAt;
  final DateTime? activatedAt;
  final DateTime? suspendedAt;
  final DateTime? cancelledAt;

  /// Set once the customer has asked to cancel: the day service ends.
  final DateTime? cancelEffectiveOn;

  /// A scheduled plan change (a downgrade) and the day it takes effect.
  final String? pendingPlanId;
  final String? pendingPlanName;
  final DateTime? planChangeOn;

  bool get isCancellationScheduled => cancelEffectiveOn != null;
  bool get hasPlanChangePending => pendingPlanId != null && planChangeOn != null;

  @override
  List<Object?> get props => [
    id, accountId, serviceNo, status, suspendReason, activationBlocker, planId,
    planName, kind, priceCents, downKbps, upKbps, billedThrough, paidThrough,
    createdAt, activatedAt, suspendedAt, cancelledAt, cancelEffectiveOn,
    pendingPlanId, pendingPlanName, planChangeOn,
  ];
}
