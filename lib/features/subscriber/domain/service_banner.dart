import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

/// Which message a service shows. Pure data: the platform's
/// `activation_blocker` (pending) and `suspend_reason` (suspended) decide it;
/// nothing is inferred from invoices or ID-check state.
enum ServiceBannerKind {
  firstInvoiceUnpaid,
  kycRequired,
  awaitingInstallation,
  customerLinkRequired,
  serviceContractRequired,

  /// Pending with no blocker the customer can act on, recurring hotspot.
  activating,

  /// Pending with no blocker the customer can act on, fixed wireless.
  providerSettingUp,
  suspendedNonPayment,
  suspendedKyc,

  /// `customer_request`, `admin` or a missing reason.
  suspendedByProvider,
}

/// What the customer can do about it in the app. Whether the target screen
/// exists yet is decided by the account entries registry, not here.
enum ServiceBannerAction { none, openInvoices, startIdCheck }

class ServiceBanner {
  const ServiceBanner(this.kind, this.action);

  final ServiceBannerKind kind;
  final ServiceBannerAction action;

  /// Pending and suspended-for-ID-check are the only gentle "do this next"
  /// states; everything else is informational. Suspended states are warnings.
  bool get isWarning => switch (kind) {
    ServiceBannerKind.suspendedNonPayment ||
    ServiceBannerKind.suspendedKyc ||
    ServiceBannerKind.suspendedByProvider => true,
    _ => false,
  };

  @override
  bool operator ==(Object other) => other is ServiceBanner && other.kind == kind && other.action == action;

  @override
  int get hashCode => Object.hash(kind, action);
}

/// The banner for [service], or null when it needs none (active, cancelled).
ServiceBanner? serviceBannerFor(SubscriberService service) {
  switch (service.status) {
    case ServiceStatus.active || ServiceStatus.cancelled:
      return null;
    case ServiceStatus.pending:
      return switch (service.activationBlocker) {
        ActivationBlocker.firstInvoiceUnpaid => const ServiceBanner(
          ServiceBannerKind.firstInvoiceUnpaid,
          ServiceBannerAction.openInvoices,
        ),
        ActivationBlocker.kycRequired => const ServiceBanner(
          ServiceBannerKind.kycRequired,
          ServiceBannerAction.startIdCheck,
        ),
        ActivationBlocker.awaitingInstallation => const ServiceBanner(
          ServiceBannerKind.awaitingInstallation,
          ServiceBannerAction.none,
        ),
        ActivationBlocker.customerLinkRequired => const ServiceBanner(
          ServiceBannerKind.customerLinkRequired,
          ServiceBannerAction.none,
        ),
        ActivationBlocker.serviceContractRequired => const ServiceBanner(
          ServiceBannerKind.serviceContractRequired,
          ServiceBannerAction.none,
        ),
        // null or a value this app version does not know.
        ActivationBlocker.unknown || null => ServiceBanner(
          service.kind == SubscriberPlanKind.fixedWireless
              ? ServiceBannerKind.providerSettingUp
              : ServiceBannerKind.activating,
          ServiceBannerAction.none,
        ),
      };
    case ServiceStatus.suspended:
      return switch (service.suspendReason) {
        SuspendReason.nonPayment => const ServiceBanner(
          ServiceBannerKind.suspendedNonPayment,
          ServiceBannerAction.openInvoices,
        ),
        SuspendReason.kyc => const ServiceBanner(ServiceBannerKind.suspendedKyc, ServiceBannerAction.startIdCheck),
        SuspendReason.customerRequest || SuspendReason.admin || null => const ServiceBanner(
          ServiceBannerKind.suspendedByProvider,
          ServiceBannerAction.none,
        ),
      };
  }
}
