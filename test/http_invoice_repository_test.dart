import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_invoice_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_invoice.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

void main() {
  late ApiHarness h;
  late HttpInvoiceRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpInvoiceRepository(h.api);
  });

  group('list', () {
    test('keeps the API order (newest first) and maps every status', () async {
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply(200, fixture('subscriber_invoices_page.json')));
      final list = _ok(await repo.list());
      expect(list.map((i) => i.invoiceNo), ['INV-000102', 'INV-000101', 'INV-000090', 'INV-000080']);
      expect(list.map((i) => i.status), [
        InvoiceStatus.open,
        InvoiceStatus.paid,
        InvoiceStatus.voided,
        InvoiceStatus.writtenOff,
      ]);
      final open = list.first;
      expect(open.amountCents, 19900);
      expect(open.vatCents, 2596);
      expect(open.dueDate, DateTime.utc(2026, 12, 1));
      expect(open.lines, isEmpty);
      expect(open.isPayable, isTrue);
      final paid = list[1];
      expect(paid.paidAt, DateTime.utc(2026, 10, 26, 8, 30));
      expect(paid.isPayable, isFalse);
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('does not sort: whatever order the API sends is the order shown', () async {
      final items = (fixtureMap('subscriber_invoices_page.json')['items']! as List).reversed.toList();
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply(200, {'items': items, 'next_cursor': null}));
      expect(_ok(await repo.list()).map((i) => i.invoiceNo), ['INV-000080', 'INV-000090', 'INV-000101', 'INV-000102']);
    });

    test('openOnly sends status=open, otherwise no status filter', () async {
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => const FakeReply(200, {'items': <Object>[], 'next_cursor': null}));
      await repo.list(openOnly: true);
      await repo.list();
      expect(h.adapter.requests[0].uri.queryParameters['status'], 'open');
      expect(h.adapter.requests[1].uri.queryParameters.containsKey('status'), isFalse);
    });

    test('follows the after cursor across two pages', () async {
      final items = fixtureMap('subscriber_invoices_page.json')['items']! as List;
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (r) {
        final after = r.uri.queryParameters['after'];
        return FakeReply(200, {
          'items': after == null ? items.take(2).toList() : items.skip(2).toList(),
          'next_cursor': after == null ? 'c2' : null,
        });
      });
      expect(_ok(await repo.list()), hasLength(4));
      expect(h.adapter.requests[1].uri.queryParameters['after'], 'c2');
    });

    test('no subscriber account is an empty list', () async {
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply.problem(404, 'subscriber_not_found'));
      expect(_ok(await repo.list()), isEmpty);
    });

    test('module off and offline are typed', () async {
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply.problem(403, 'module_not_enabled'));
      expect(_failure(await repo.list()), isA<ModuleDisabledFailure>());
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.list()), isA<NetworkFailure>());
    });

    test('an unknown status is refused, an unknown kind is kept as sent', () async {
      final first = Map<String, Object?>.from((fixtureMap('subscriber_invoices_page.json')['items']! as List).first as Map);
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply(200, {'items': [{...first, 'status': 'frozen'}], 'next_cursor': null}));
      expect(_failure(await repo.list()), isA<ServerFailure>());
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply(200, {'items': [{...first, 'kind': 'surcharge'}], 'next_cursor': null}));
      expect(_ok(await repo.list()).single.kind, 'surcharge');
    });

    test('a currency other than ZAR is refused', () async {
      final first = Map<String, Object?>.from((fixtureMap('subscriber_invoices_page.json')['items']! as List).first as Map);
      h.adapter.on('GET', '/v1/me/subscriber/invoices', (_) => FakeReply(200, {'items': [{...first, 'amount': {'amount_cents': 1, 'currency': 'USD'}}], 'next_cursor': null}));
      expect(_failure(await repo.list()), isA<ServerFailure>());
    });
  });

  group('get', () {
    test('maps the lines, VAT and dates without shifting them', () async {
      h.adapter.on('GET', '/v1/me/subscriber/invoices/inv1', (_) => FakeReply(200, fixture('subscriber_invoice.json')));
      final invoice = _ok(await repo.get('inv1'));
      expect(invoice.lines, hasLength(1));
      expect(invoice.lines.single.description, 'Home Hotspot 10, December 2026');
      expect(invoice.lines.single.vatRateBp, 1500);
      expect(invoice.periodStart, parseApiDate('2026-12-01'));
      expect(invoice.issueDate.day, 25);
      expect(invoice.isOpen, isTrue);
    });

    test('part paid is open but not payable', () async {
      final base = fixtureMap('subscriber_invoice.json');
      h.adapter.on('GET', '/v1/me/subscriber/invoices/inv1', (_) => FakeReply(200, {...base, 'amount_paid_cents': 5000}));
      final invoice = _ok(await repo.get('inv1'));
      expect(invoice.isPartPaid, isTrue);
      expect(invoice.isPayable, isFalse);
    });

    test('a nil-amount open invoice is not payable', () async {
      final base = fixtureMap('subscriber_invoice.json');
      h.adapter.on('GET', '/v1/me/subscriber/invoices/inv1', (_) => FakeReply(200, {...base, 'amount': {'amount_cents': 0, 'currency': 'ZAR'}}));
      expect(_ok(await repo.get('inv1')).isPayable, isFalse);
    });

    test('404 invoice_not_found is a NotFoundFailure', () async {
      h.adapter.on('GET', '/v1/me/subscriber/invoices/inv1', (_) => FakeReply.problem(404, 'invoice_not_found'));
      expect(_failure(await repo.get('inv1')), isA<NotFoundFailure>());
    });
  });

  group('startCheckout', () {
    test('posts with the given Idempotency-Key and reads the same hand-off as an order', () async {
      h.adapter.on('POST', '/v1/me/subscriber/invoices/inv1/checkout', (_) => FakeReply(200, fixture('invoice_checkout.json')));
      final handoff = _ok(await repo.startCheckout('inv1', idempotencyKey: 'app-invoice-key-1'));
      expect(handoff.gateway, 'netcash');
      expect(handoff.method, PaymentHandoffMethod.post);
      expect(handoff.amountCents, 19900);
      expect(handoff.url.host, 'paynow.netcash.co.za');
      expect(h.adapter.requests.single.headers['Idempotency-Key'], 'app-invoice-key-1');
    });

    test('a server that claims the demo gateway is refused', () async {
      final demo = {...fixtureMap('invoice_checkout.json'), 'gateway': 'demo'};
      h.adapter.on('POST', '/v1/me/subscriber/invoices/inv1/checkout', (_) => FakeReply(200, demo));
      expect(_failure(await repo.startCheckout('inv1', idempotencyKey: 'app-invoice-key-1')), isA<ServerFailure>());
    });

    final refusals = <(int, String, Type)>[
      (409, 'invoice_not_payable', InvoiceNotPayableFailure),
      (409, 'collection_mode_not_supported', CollectionExternalFailure),
      (409, 'customer_not_active', AccountProblemFailure),
      (409, 'account_not_active', AccountProblemFailure),
      (409, 'account_changed', AccountProblemFailure),
      (404, 'invoice_not_found', NotFoundFailure),
      (403, 'tenant_suspended', ProviderUnavailableFailure),
      (409, 'customer_link_required', CustomerLinkRequiredFailure),
    ];
    for (final (status, code, type) in refusals) {
      test('$status $code is typed', () async {
        h.adapter.on('POST', '/v1/me/subscriber/invoices/inv1/checkout', (_) => FakeReply.problem(status, code));
        expect(_failure(await repo.startCheckout('inv1', idempotencyKey: 'app-invoice-key-1')).runtimeType, type);
      });
    }

    test('offline is a NetworkFailure', () async {
      h.adapter.on('POST', '/v1/me/subscriber/invoices/inv1/checkout', (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.startCheckout('inv1', idempotencyKey: 'app-invoice-key-1')), isA<NetworkFailure>());
    });
  });
}
