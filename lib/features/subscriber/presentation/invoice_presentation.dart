import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/l10n/l10n.dart';

/// A plain calendar date (`parseApiDate` value) as text. Reads year, month and
/// day as stored and never converts the zone, so a business date cannot shift.
String formatInvoiceDate(BuildContext context, DateTime date) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).format(DateTime(date.year, date.month, date.day));

/// An instant (`paid_at`) in the device's zone.
String formatInvoiceInstant(BuildContext context, DateTime instant) =>
    DateFormat.yMMMd(Localizations.localeOf(context).toLanguageTag()).add_Hm().format(instant.toLocal());

String invoiceKindLabel(AppLocalizations l10n, String kind) => switch (kind) {
  'initial' => l10n.invoiceKindInitial,
  'recurring' => l10n.invoiceKindRecurring,
  'proration' => l10n.invoiceKindProration,
  'reactivation' => l10n.invoiceKindReactivation,
  'adjustment' => l10n.invoiceKindAdjustment,
  _ => l10n.invoiceKindOther,
};

String invoiceStatusLabel(AppLocalizations l10n, InvoiceStatus status) => switch (status) {
  InvoiceStatus.open => l10n.invoiceStatusOpen,
  InvoiceStatus.paid => l10n.invoiceStatusPaid,
  InvoiceStatus.voided => l10n.invoiceStatusVoid,
  InvoiceStatus.writtenOff => l10n.invoiceStatusWrittenOff,
};

/// What happens to the service after its invoice is paid. Paying does not
/// always start the service; the platform's `activation_blocker` says which
/// gate is left, and this only maps it (no inference from other sources).
enum InvoicePaidOutcome { thanks, kycNeeded, installation, contactProvider, activating, settingUp }

InvoicePaidOutcome invoicePaidOutcome(SubscriberService? service) {
  if (service == null || service.status != ServiceStatus.pending) return InvoicePaidOutcome.thanks;
  return switch (service.activationBlocker) {
    ActivationBlocker.kycRequired => InvoicePaidOutcome.kycNeeded,
    ActivationBlocker.awaitingInstallation => InvoicePaidOutcome.installation,
    ActivationBlocker.customerLinkRequired || ActivationBlocker.serviceContractRequired => InvoicePaidOutcome.contactProvider,
    // No blocker, an unknown one, or "first invoice unpaid" (the platform has
    // not processed the payment yet): the generic line for the plan kind.
    ActivationBlocker.firstInvoiceUnpaid ||
    ActivationBlocker.unknown ||
    null => service.kind == SubscriberPlanKind.fixedWireless ? InvoicePaidOutcome.settingUp : InvoicePaidOutcome.activating,
  };
}

String invoicePaidOutcomeText(AppLocalizations l10n, InvoicePaidOutcome outcome) => switch (outcome) {
  InvoicePaidOutcome.thanks => l10n.invoicePaidThanks,
  InvoicePaidOutcome.kycNeeded => l10n.invoicePaidKyc,
  InvoicePaidOutcome.installation => l10n.invoicePaidInstallation,
  InvoicePaidOutcome.contactProvider => l10n.invoicePaidContactProvider,
  InvoicePaidOutcome.activating => l10n.invoicePaidActivating,
  InvoicePaidOutcome.settingUp => l10n.invoicePaidSettingUp,
};

/// Small coloured status chip.
class InvoiceStatusChip extends StatelessWidget {
  const InvoiceStatusChip({super.key, required this.status});

  final InvoiceStatus status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (background, foreground) = switch (status) {
      InvoiceStatus.open => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      InvoiceStatus.paid => (scheme.primaryContainer, scheme.onPrimaryContainer),
      InvoiceStatus.voided || InvoiceStatus.writtenOff => (scheme.surfaceContainerHighest, scheme.onSurfaceVariant),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(999)),
      child: Text(
        invoiceStatusLabel(context.l10n, status),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
      ),
    );
  }
}
