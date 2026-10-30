import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';

/// Demo flavor only: one open and one paid invoice for the demo service.
/// "Paying" in the demo marks the invoice paid at once.
class MockInvoiceRepository implements InvoiceRepository {
  MockInvoiceRepository({this._latency = const Duration(milliseconds: 250)});

  final Duration _latency;

  static const _openId = '9a1b2c3d-0000-4000-8000-0000000000c2';
  static const _paidId = '9a1b2c3d-0000-4000-8000-0000000000c1';

  late List<SubscriberInvoice> _invoices = [
    SubscriberInvoice(
      id: _openId,
      serviceId: MockSubscriberRepository.mockService.id,
      invoiceNo: 'INV-000102',
      kind: 'recurring',
      status: InvoiceStatus.open,
      periodStart: DateTime.utc(2026, 12),
      periodEnd: DateTime.utc(2026, 12, 31),
      issueDate: DateTime.utc(2026, 11, 25),
      dueDate: DateTime.utc(2026, 12, 1),
      amountCents: 19900,
      vatCents: 2596,
      amountPaidCents: 0,
      lines: const [
        InvoiceLine(
          position: 1,
          kind: 'plan',
          description: 'Home Hotspot 10, December 2026',
          quantity: 1,
          unitPriceCents: 19900,
          lineTotalCents: 19900,
          vatRateBp: 1500,
          vatCents: 2596,
        ),
      ],
    ),
    SubscriberInvoice(
      id: _paidId,
      serviceId: MockSubscriberRepository.mockService.id,
      invoiceNo: 'INV-000101',
      kind: 'initial',
      status: InvoiceStatus.paid,
      periodStart: DateTime.utc(2026, 11),
      periodEnd: DateTime.utc(2026, 11, 30),
      issueDate: DateTime.utc(2026, 10, 25),
      dueDate: DateTime.utc(2026, 11, 1),
      amountCents: 19900,
      vatCents: 2596,
      amountPaidCents: 19900,
      paidAt: DateTime.utc(2026, 10, 26, 8, 30),
      lines: const [
        InvoiceLine(
          position: 1,
          kind: 'plan',
          description: 'Home Hotspot 10, November 2026',
          quantity: 1,
          unitPriceCents: 19900,
          lineTotalCents: 19900,
          vatRateBp: 1500,
          vatCents: 2596,
        ),
      ],
    ),
  ];

  static final _demoHandoff = PaymentHandoff(
    paymentId: 'demo-invoice-payment',
    reference: 'DEMO-INV',
    gateway: PaymentHandoff.demoGateway,
    method: PaymentHandoffMethod.get,
    url: Uri.parse('about:blank'),
    amountCents: 19900,
  );

  @override
  Future<Either<Failure, List<SubscriberInvoice>>> list({bool openOnly = false}) async {
    await Future<void>.delayed(_latency);
    return Right([
      for (final i in _invoices)
        if (!openOnly || i.isOpen) _withoutLines(i),
    ]);
  }

  @override
  Future<Either<Failure, SubscriberInvoice>> get(String id) async {
    await Future<void>.delayed(_latency);
    for (final i in _invoices) {
      if (i.id == id) return Right(i);
    }
    return const Left(NotFoundFailure());
  }

  @override
  Future<Either<Failure, PaymentHandoff>> startCheckout(String id, {required String idempotencyKey}) async {
    await Future<void>.delayed(_latency);
    final index = _invoices.indexWhere((i) => i.id == id);
    if (index == -1) return const Left(NotFoundFailure());
    final invoice = _invoices[index];
    if (!invoice.isPayable) return const Left(InvoiceNotPayableFailure());
    _invoices = [..._invoices]
      ..[index] = SubscriberInvoice(
        id: invoice.id,
        serviceId: invoice.serviceId,
        invoiceNo: invoice.invoiceNo,
        kind: invoice.kind,
        status: InvoiceStatus.paid,
        periodStart: invoice.periodStart,
        periodEnd: invoice.periodEnd,
        issueDate: invoice.issueDate,
        dueDate: invoice.dueDate,
        amountCents: invoice.amountCents,
        vatCents: invoice.vatCents,
        amountPaidCents: invoice.amountCents,
        paidAt: DateTime.now().toUtc(),
        lines: invoice.lines,
      );
    return Right(_demoHandoff);
  }

  /// The real list carries no lines.
  SubscriberInvoice _withoutLines(SubscriberInvoice i) => SubscriberInvoice(
    id: i.id,
    serviceId: i.serviceId,
    invoiceNo: i.invoiceNo,
    kind: i.kind,
    status: i.status,
    periodStart: i.periodStart,
    periodEnd: i.periodEnd,
    issueDate: i.issueDate,
    dueDate: i.dueDate,
    amountCents: i.amountCents,
    vatCents: i.vatCents,
    amountPaidCents: i.amountPaidCents,
    paidAt: i.paidAt,
  );
}
