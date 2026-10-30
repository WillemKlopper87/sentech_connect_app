import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';

/// Decoders for the invoice API models. `status` is a closed API enum, so an
/// unknown value fails loudly with [FormatException] (the client turns that
/// into a `ServerFailure`); `kind` is a free string and is kept as sent.

InvoiceStatus invoiceStatusFromApi(Object? value) => switch (value) {
  'open' => InvoiceStatus.open,
  'paid' => InvoiceStatus.paid,
  'void' => InvoiceStatus.voided,
  'written_off' => InvoiceStatus.writtenOff,
  final other => throw FormatException('Unknown invoice status $other'),
};

int _moneyCents(Object? money) {
  final map = money! as Map;
  final currency = map['currency'];
  // `Money` always carries a currency; ZAR is the only one the app speaks.
  if (currency != null && currency != 'ZAR') throw FormatException('Unsupported currency $currency');
  return map['amount_cents']! as int;
}

/// `SubscriberInvoiceLineOut` -> [InvoiceLine].
InvoiceLine invoiceLineFromJson(Map<String, Object?> json) => InvoiceLine(
  position: json['position']! as int,
  kind: json['kind']! as String,
  description: json['description']! as String,
  quantity: json['quantity']! as int,
  unitPriceCents: json['unit_price_cents']! as int,
  lineTotalCents: json['line_total_cents']! as int,
  vatRateBp: json['vat_rate_bp']! as int,
  vatCents: json['vat_cents']! as int,
);

/// `SubscriberInvoiceOut` -> [SubscriberInvoice].
SubscriberInvoice subscriberInvoiceFromJson(Map<String, Object?> json) {
  final paidAt = json['paid_at'];
  final lines = json['lines'] as List? ?? const [];
  return SubscriberInvoice(
    id: json['id']! as String,
    serviceId: json['service_id']! as String,
    invoiceNo: json['invoice_no']! as String,
    kind: json['kind']! as String,
    status: invoiceStatusFromApi(json['status']),
    periodStart: parseApiDate(json['period_start']! as String),
    periodEnd: parseApiDate(json['period_end']! as String),
    issueDate: parseApiDate(json['issue_date']! as String),
    dueDate: parseApiDate(json['due_date']! as String),
    amountCents: _moneyCents(json['amount']),
    vatCents: json['vat_cents']! as int,
    amountPaidCents: json['amount_paid_cents']! as int,
    paidAt: paidAt == null ? null : DateTime.parse(paidAt as String).toUtc(),
    lines: [for (final raw in lines) invoiceLineFromJson(Map<String, Object?>.from(raw as Map))],
  );
}
