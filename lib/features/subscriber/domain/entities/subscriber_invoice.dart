import 'package:equatable/equatable.dart';

/// `SubscriberInvoiceOut.status`. The API enum is closed.
enum InvoiceStatus { open, paid, voided, writtenOff }

/// One line of an invoice (`SubscriberInvoiceLineOut`). Amounts are gross
/// cents; [vatCents] is the VAT contained in [lineTotalCents].
class InvoiceLine extends Equatable {
  const InvoiceLine({
    required this.position,
    required this.kind,
    required this.description,
    required this.quantity,
    required this.unitPriceCents,
    required this.lineTotalCents,
    required this.vatRateBp,
    required this.vatCents,
  });

  final int position;
  final String kind;
  final String description;
  final int quantity;
  final int unitPriceCents;
  final int lineTotalCents;
  final int vatRateBp;
  final int vatCents;

  @override
  List<Object?> get props => [position, kind, description, quantity, unitPriceCents, lineTotalCents, vatRateBp, vatCents];
}

/// An invoice on the customer's subscriber account (`SubscriberInvoiceOut`).
/// `*Date`, [periodStart] and [periodEnd] are plain calendar dates (see
/// `parseApiDate`); [paidAt] is an instant in UTC. List responses carry no
/// [lines]; the detail does.
class SubscriberInvoice extends Equatable {
  const SubscriberInvoice({
    required this.id,
    required this.serviceId,
    required this.invoiceNo,
    required this.kind,
    required this.status,
    required this.periodStart,
    required this.periodEnd,
    required this.issueDate,
    required this.dueDate,
    required this.amountCents,
    required this.vatCents,
    required this.amountPaidCents,
    this.paidAt,
    this.lines = const [],
  });

  final String id;
  final String serviceId;
  final String invoiceNo;

  /// Free string on the API (`initial`, `recurring`, `proration`,
  /// `reactivation`, `adjustment`, maybe more); shown through a lookup with a
  /// safe default.
  final String kind;
  final InvoiceStatus status;
  final DateTime periodStart;
  final DateTime periodEnd;
  final DateTime issueDate;
  final DateTime dueDate;

  /// Gross amount due, VAT included.
  final int amountCents;
  final int vatCents;
  final int amountPaidCents;
  final DateTime? paidAt;
  final List<InvoiceLine> lines;

  bool get isOpen => status == InvoiceStatus.open;

  /// Open with something already paid: the platform refuses to start another
  /// payment for it, so the app offers no Pay action (contact support).
  bool get isPartPaid => isOpen && amountPaidCents > 0;

  /// The platform only takes payment for an open invoice with an amount and
  /// nothing paid yet (`409 invoice_not_payable` otherwise).
  bool get isPayable => isOpen && amountCents > 0 && amountPaidCents == 0;

  @override
  List<Object?> get props => [
    id, serviceId, invoiceNo, kind, status, periodStart, periodEnd, issueDate,
    dueDate, amountCents, vatCents, amountPaidCents, paidAt, lines,
  ];
}
