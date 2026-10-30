import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

/// Which message a service shows. Pure data: the platform's
/// `activation_blocker` (pending) and `suspend_reason` (suspended) decide it;
/// nothing is inferred from invoices or ID-check state.
enum ServiceBannerKind {
  firstInvoiceUnpaid,
  kycRequired,

  /// An ID check is already with the provider (kyc status `pending`): the
  /// service waits for it, there is nothing for the customer to do.
  kycChecking,
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

/// True when [kycStatus] (the ID check status) can change what [service]
/// shows, so a screen only reads it for such services.
bool serviceBannerUsesKyc(SubscriberService service) =>
    (service.status == ServiceStatus.pending && service.activationBlocker == ActivationBlocker.kycRequired) ||
    (service.status == ServiceStatus.suspended && service.suspendReason == SuspendReason.kyc);

/// The banner for [service], or null when it needs none (active, cancelled).
///
/// [kyc] is the customer's ID check status when it is known (null: no check
/// yet, not loaded, or unreadable, which keeps today's generic messages). It
/// only matters for the two ID-check states: a `pending` check says "we are
/// checking your ID"; a `verified` one no longer asks for a check (the platform
/// is about to lift the block, so the generic message shows); a `rejected` one
/// still asks for a new check.
ServiceBanner? serviceBannerFor(SubscriberService service, {KycStatus? kyc}) {
  switch (service.status) {
    case ServiceStatus.active || ServiceStatus.cancelled:
      return null;
    case ServiceStatus.pending:
      return switch (service.activationBlocker) {
        ActivationBlocker.firstInvoiceUnpaid => const ServiceBanner(
          ServiceBannerKind.firstInvoiceUnpaid,
          ServiceBannerAction.openInvoices,
        ),
        ActivationBlocker.kycRequired => switch (kyc) {
          KycStatus.pending => const ServiceBanner(ServiceBannerKind.kycChecking, ServiceBannerAction.none),
          KycStatus.verified => _activating(service),
          KycStatus.rejected || null => const ServiceBanner(
            ServiceBannerKind.kycRequired,
            ServiceBannerAction.startIdCheck,
          ),
        },
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
        ActivationBlocker.unknown || null => _activating(service),
      };
    case ServiceStatus.suspended:
      return switch (service.suspendReason) {
        SuspendReason.nonPayment => const ServiceBanner(
          ServiceBannerKind.suspendedNonPayment,
          ServiceBannerAction.openInvoices,
        ),
        SuspendReason.kyc => switch (kyc) {
          KycStatus.pending => const ServiceBanner(ServiceBannerKind.kycChecking, ServiceBannerAction.none),
          KycStatus.verified => const ServiceBanner(ServiceBannerKind.suspendedByProvider, ServiceBannerAction.none),
          KycStatus.rejected || null => const ServiceBanner(
            ServiceBannerKind.suspendedKyc,
            ServiceBannerAction.startIdCheck,
          ),
        },
        SuspendReason.customerRequest || SuspendReason.admin || null => const ServiceBanner(
          ServiceBannerKind.suspendedByProvider,
          ServiceBannerAction.none,
        ),
      };
  }
}

/// Pending with no blocker the customer can act on.
ServiceBanner _activating(SubscriberService service) => ServiceBanner(
  service.kind == SubscriberPlanKind.fixedWireless ? ServiceBannerKind.providerSettingUp : ServiceBannerKind.activating,
  ServiceBannerAction.none,
);
