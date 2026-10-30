import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/bloc/payment_cubit.dart' show defaultPollDelays;
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/repositories/invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/bloc/invoice_payment_cubit.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/invoice_presentation.dart';

import 'helpers/fake_subscriber_repository.dart';

final _handoff = PaymentHandoff(
  paymentId: 'pay1',
  reference: 'SC1',
  gateway: 'netcash',
  method: PaymentHandoffMethod.post,
  url: Uri.parse('https://paynow.netcash.co.za/site/paynow.aspx'),
  amountCents: 19900,
);

SubscriberInvoice _invoice(InvoiceStatus status) => SubscriberInvoice(
  id: 'inv1',
  serviceId: MockSubscriberRepository.mockService.id,
  invoiceNo: 'INV-1',
  kind: 'recurring',
  status: status,
  periodStart: DateTime.utc(2026, 12),
  periodEnd: DateTime.utc(2026, 12, 31),
  issueDate: DateTime.utc(2026, 11, 25),
  dueDate: DateTime.utc(2026, 12, 1),
  amountCents: 19900,
  vatCents: 2596,
  amountPaidCents: status == InvoiceStatus.paid ? 19900 : 0,
);

/// Checkout and each poll take the next scripted reply.
class _ScriptedInvoices implements InvoiceRepository {
  _ScriptedInvoices({List<Either<Failure, InvoiceStatus>>? polls}) : polls = polls ?? [];

  final List<Either<Failure, InvoiceStatus>> polls;
  Either<Failure, PaymentHandoff> startResult = Right(_handoff);
  final keys = <String>[];
  int getCalls = 0;
  Completer<void>? startGate;

  @override
  Future<Either<Failure, List<SubscriberInvoice>>> list({bool openOnly = false}) async => const Right([]);

  @override
  Future<Either<Failure, SubscriberInvoice>> get(String id) async {
    getCalls++;
    final next = polls.isEmpty ? const Right<Failure, InvoiceStatus>(InvoiceStatus.open) : polls.removeAt(0);
    return next.map(_invoice);
  }

  @override
  Future<Either<Failure, PaymentHandoff>> startCheckout(String id, {required String idempotencyKey}) async {
    keys.add(idempotencyKey);
    await startGate?.future;
    return startResult;
  }
}

void main() {
  final waits = <Duration>[];
  var keyCounter = 0;

  setUp(() {
    waits.clear();
    keyCounter = 0;
  });

  InvoicePaymentCubit cubit(_ScriptedInvoices invoices, {FakeSubscriberRepository? subscriber, List<Duration>? delays}) =>
      InvoicePaymentCubit(
        invoices,
        subscriber ?? FakeSubscriberRepository(),
        'inv1',
        pollDelays: delays ?? defaultPollDelays,
        wait: (d) async => waits.add(d),
        newKey: () => 'key-${++keyCounter}',
      );

  test('starts with a key, hands off, then polls the invoice until the server says paid', () async {
    final invoices = _ScriptedInvoices(polls: [
      const Right(InvoiceStatus.open),
      const Right(InvoiceStatus.open),
      const Right(InvoiceStatus.paid),
    ]);
    final c = cubit(invoices);
    await c.pay();
    expect(c.state.status, InvoicePaymentStatus.handoff);
    expect(c.state.handoff, _handoff);
    expect(invoices.keys, ['key-1']);
    await c.handoffFinished();
    expect(c.state.status, InvoicePaymentStatus.paid);
    expect(invoices.getCalls, 3);
    expect(waits, defaultPollDelays.take(3).toList());
    expect(c.state.invoice!.status, InvoiceStatus.paid);
    await c.close();
  });

  test('after payment the service is re-read so the outcome is the platform blocker', () async {
    final subscriber = FakeSubscriberRepository(service: _pendingService(ActivationBlocker.kycRequired));
    final c = cubit(_ScriptedInvoices(polls: [const Right(InvoiceStatus.paid)]), subscriber: subscriber);
    await c.pay();
    await c.handoffFinished();
    expect(c.state.status, InvoicePaymentStatus.paid);
    expect(subscriber.getServiceCalls, [MockSubscriberRepository.mockService.id]);
    expect(invoicePaidOutcome(c.state.service), InvoicePaidOutcome.kycNeeded);
    await c.close();
  });

  test('a service that cannot be read does not undo the payment', () async {
    final subscriber = FakeSubscriberRepository(failure: const NetworkFailure());
    final c = cubit(_ScriptedInvoices(polls: [const Right(InvoiceStatus.paid)]), subscriber: subscriber);
    await c.pay();
    await c.handoffFinished();
    expect(c.state.status, InvoicePaymentStatus.paid);
    expect(c.state.service, isNull);
    expect(invoicePaidOutcome(c.state.service), InvoicePaidOutcome.thanks);
    await c.close();
  });

  test('no confirmation within the window is stillPending, and Check again can finish it', () async {
    final invoices = _ScriptedInvoices();
    final c = cubit(invoices, delays: const [Duration.zero, Duration(seconds: 1)]);
    await c.pay();
    await c.handoffFinished();
    expect(c.state.status, InvoicePaymentStatus.stillPending);
    invoices.polls.add(const Right(InvoiceStatus.paid));
    await c.checkAgain();
    expect(c.state.status, InvoicePaymentStatus.paid);
    await c.close();
  });

  test('an offline blip while polling does not end the wait', () async {
    final invoices = _ScriptedInvoices(polls: [const Left(NetworkFailure()), const Right(InvoiceStatus.paid)]);
    final c = cubit(invoices);
    await c.pay();
    await c.handoffFinished();
    expect(c.state.status, InvoicePaymentStatus.paid);
    await c.close();
  });

  test('an invoice that turns void while waiting closes the flow', () async {
    final c = cubit(_ScriptedInvoices(polls: [const Right(InvoiceStatus.voided)]));
    await c.pay();
    await c.handoffFinished();
    expect(c.state.status, InvoicePaymentStatus.closed);
    expect(c.state.failure, isA<InvoiceNotPayableFailure>());
    await c.close();
  });

  test('a provider that collects its own money closes the flow without a retry', () async {
    final invoices = _ScriptedInvoices()..startResult = const Left(CollectionExternalFailure());
    final c = cubit(invoices);
    await c.pay();
    expect(c.state.status, InvoicePaymentStatus.closed);
    expect(c.state.failure, isA<CollectionExternalFailure>());
    await c.pay();
    expect(invoices.keys, hasLength(1));
    await c.close();
  });

  test('invoice_not_payable re-reads the invoice: paid late shows paid, otherwise closed', () async {
    final late = _ScriptedInvoices(polls: [const Right(InvoiceStatus.paid)])..startResult = const Left(InvoiceNotPayableFailure());
    final a = cubit(late);
    await a.pay();
    expect(a.state.status, InvoicePaymentStatus.paid);
    await a.close();

    final closed = _ScriptedInvoices(polls: [const Right(InvoiceStatus.voided)])..startResult = const Left(InvoiceNotPayableFailure());
    final b = cubit(closed);
    await b.pay();
    expect(b.state.status, InvoicePaymentStatus.closed);
    expect(b.state.failure, isA<InvoiceNotPayableFailure>());
    await b.close();
  });

  test('a lost response (offline) retries with the same key; a refusal gets a new one', () async {
    final invoices = _ScriptedInvoices()..startResult = const Left(NetworkFailure());
    final c = cubit(invoices);
    await c.pay();
    expect(c.state.status, InvoicePaymentStatus.payFailed);
    await c.pay();
    expect(invoices.keys, ['key-1', 'key-1']);
    invoices.startResult = const Left(ValidationFailure('no', 'x'));
    await c.pay();
    await c.pay();
    expect(invoices.keys, ['key-1', 'key-1', 'key-1', 'key-2']);
    await c.close();
  });

  test('an unsafe hand-off URL is never opened', () async {
    final invoices = _ScriptedInvoices()
      ..startResult = Right(
        PaymentHandoff(
          paymentId: 'p',
          reference: 'r',
          gateway: 'evil',
          method: PaymentHandoffMethod.get,
          url: Uri.parse('http://evil.example/pay'),
          amountCents: 1,
        ),
      );
    final c = cubit(invoices);
    await c.pay();
    expect(c.state.status, InvoicePaymentStatus.payFailed);
    expect((c.state.failure! as ValidationFailure).code, InvoicePaymentCubit.handoffInvalidCode);
    await c.close();
  });

  test('a second tap while the payment is starting does nothing', () async {
    final invoices = _ScriptedInvoices()..startGate = Completer<void>();
    final c = cubit(invoices);
    final first = c.pay();
    await Future<void>.delayed(Duration.zero);
    expect(c.state.status, InvoicePaymentStatus.starting);
    await c.pay();
    invoices.startGate!.complete();
    await first;
    expect(invoices.keys, hasLength(1));
    await c.close();
  });

  group('invoicePaidOutcome', () {
    test('maps the platform blocker and nothing else', () {
      expect(invoicePaidOutcome(null), InvoicePaidOutcome.thanks);
      expect(invoicePaidOutcome(MockSubscriberRepository.mockService), InvoicePaidOutcome.thanks);
      expect(invoicePaidOutcome(_pendingService(ActivationBlocker.kycRequired)), InvoicePaidOutcome.kycNeeded);
      expect(invoicePaidOutcome(_pendingService(ActivationBlocker.awaitingInstallation)), InvoicePaidOutcome.installation);
      expect(invoicePaidOutcome(_pendingService(ActivationBlocker.customerLinkRequired)), InvoicePaidOutcome.contactProvider);
      expect(invoicePaidOutcome(_pendingService(ActivationBlocker.serviceContractRequired)), InvoicePaidOutcome.contactProvider);
      expect(invoicePaidOutcome(_pendingService(null)), InvoicePaidOutcome.activating);
      expect(invoicePaidOutcome(_pendingService(ActivationBlocker.unknown)), InvoicePaidOutcome.activating);
      expect(invoicePaidOutcome(_pendingService(ActivationBlocker.firstInvoiceUnpaid)), InvoicePaidOutcome.activating);
      expect(
        invoicePaidOutcome(_pendingService(null, kind: SubscriberPlanKind.fixedWireless)),
        InvoicePaidOutcome.settingUp,
      );
    });
  });
}

SubscriberService _pendingService(ActivationBlocker? blocker, {SubscriberPlanKind kind = SubscriberPlanKind.recurringHotspot}) {
  final base = MockSubscriberRepository.mockService;
  return SubscriberService(
    id: base.id,
    accountId: base.accountId,
    serviceNo: base.serviceNo,
    status: ServiceStatus.pending,
    activationBlocker: blocker,
    planId: base.planId,
    planName: base.planName,
    kind: kind,
    priceCents: base.priceCents,
    downKbps: base.downKbps,
    upKbps: base.upKbps,
    createdAt: base.createdAt,
  );
}
