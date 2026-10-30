import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_banner.dart';

import 'helpers/subscriber_service_fixtures.dart';

void main() {
  group('pending: activation_blocker decides', () {
    const table = {
      ActivationBlocker.firstInvoiceUnpaid: (ServiceBannerKind.firstInvoiceUnpaid, ServiceBannerAction.openInvoices),
      ActivationBlocker.kycRequired: (ServiceBannerKind.kycRequired, ServiceBannerAction.startIdCheck),
      ActivationBlocker.awaitingInstallation: (ServiceBannerKind.awaitingInstallation, ServiceBannerAction.none),
      ActivationBlocker.customerLinkRequired: (ServiceBannerKind.customerLinkRequired, ServiceBannerAction.none),
      ActivationBlocker.serviceContractRequired: (ServiceBannerKind.serviceContractRequired, ServiceBannerAction.none),
    };
    for (final e in table.entries) {
      test('${e.key.name} -> ${e.value.$1.name}', () {
        final b = serviceBannerFor(testService(status: ServiceStatus.pending, activationBlocker: e.key));
        expect(b, ServiceBanner(e.value.$1, e.value.$2));
      });
    }

    for (final blocker in [null, ActivationBlocker.unknown]) {
      test('$blocker on a hotspot: generic activating copy', () {
        final b = serviceBannerFor(testService(status: ServiceStatus.pending, activationBlocker: blocker));
        expect(b, const ServiceBanner(ServiceBannerKind.activating, ServiceBannerAction.none));
      });
      test('$blocker on fixed wireless: provider is setting it up', () {
        final b = serviceBannerFor(
          testService(
            status: ServiceStatus.pending,
            kind: SubscriberPlanKind.fixedWireless,
            activationBlocker: blocker,
          ),
        );
        expect(b, const ServiceBanner(ServiceBannerKind.providerSettingUp, ServiceBannerAction.none));
      });
    }
  });

  group('suspended: suspend_reason decides', () {
    const table = {
      SuspendReason.nonPayment: (ServiceBannerKind.suspendedNonPayment, ServiceBannerAction.openInvoices),
      SuspendReason.kyc: (ServiceBannerKind.suspendedKyc, ServiceBannerAction.startIdCheck),
      SuspendReason.customerRequest: (ServiceBannerKind.suspendedByProvider, ServiceBannerAction.none),
      SuspendReason.admin: (ServiceBannerKind.suspendedByProvider, ServiceBannerAction.none),
      null: (ServiceBannerKind.suspendedByProvider, ServiceBannerAction.none),
    };
    for (final e in table.entries) {
      test('${e.key} -> ${e.value.$1.name}', () {
        final b = serviceBannerFor(testService(status: ServiceStatus.suspended, suspendReason: e.key));
        expect(b, ServiceBanner(e.value.$1, e.value.$2));
        expect(b!.isWarning, isTrue);
      });
    }
  });

  test('active and cancelled services have no banner', () {
    expect(serviceBannerFor(testService()), isNull);
    expect(serviceBannerFor(testService(status: ServiceStatus.cancelled)), isNull);
  });

  test('a blocker on a non-pending service is ignored', () {
    expect(serviceBannerFor(testService(activationBlocker: ActivationBlocker.kycRequired)), isNull);
  });
}
