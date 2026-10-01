import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/cart/domain/entities/cart_item.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _pass = Plan(
  id: '0b0c3a52-6f43-4c39-9a8e-0d6f2f0e1a01',
  name: '1 Hour Pass',
  priceCents: 1500,
  dataDescription: '1 GB · 1 hour',
  speedMbps: 10,
  category: ProductCategory.hotspotPass,
);

void main() {
  late ApiHarness h;
  late HttpCheckoutRepository repo;

  setUp(() async {
    h = ApiHarness();
    repo = HttpCheckoutRepository(h.api, newKey: () => 'app-generated-key');
    await h.signIn();
  });

  test(
    'createOrder sends product ids and quantities with the caller key; the server owns the total',
    () async {
      h.adapter.on(
        'POST',
        '/v1/orders',
        (_) => FakeReply(201, fixture('order_draft.json')),
      );
      final order = (await repo.createOrder(
        items: const [CartItem(plan: _pass, quantity: 2)],
        idempotencyKey: 'app-cart-key-123',
      )).getOrElse((f) => throw StateError(f.message));

      final sent = h.adapter.requestsTo('POST', '/v1/orders').single;
      expect(sent.data, {
        'lines': [
          {'product_id': _pass.id, 'quantity': 2},
        ],
      });
      expect(sent.headers['Idempotency-Key'], 'app-cart-key-123');
      expect(order.id, '5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f10');
      expect(
        order.status,
        OrderStatus.awaitingPayment,
      ); // hotspot passes skip RICA
      expect(order.totalCents, 3000);
      expect(order.orderNumber, 'SC-5E9B7C1A');
      expect(order.planName, '1 Hour Pass × 2');
    },
  );

  test('createOrder without a key still sends one', () async {
    h.adapter.on(
      'POST',
      '/v1/orders',
      (_) => FakeReply(201, fixture('order_draft.json')),
    );
    await repo.createOrder(items: const [CartItem(plan: _pass, quantity: 1)]);
    expect(
      h.adapter.requests.single.headers['Idempotency-Key'],
      'app-generated-key',
    );
  });

  test('an empty cart never reaches the server', () async {
    expect((await repo.createOrder(items: const [])).isLeft(), isTrue);
    expect(h.adapter.requests, isEmpty);
  });

  test(
    'server-side validation (e.g. an inactive pass) comes back as a ValidationFailure',
    () async {
      h.adapter.on(
        'POST',
        '/v1/orders',
        (_) => FakeReply.problem(
          422,
          'product_unavailable',
          detail: 'That pass is no longer on sale.',
        ),
      );
      final failure = (await repo.createOrder(
        items: const [CartItem(plan: _pass, quantity: 1)],
      )).match((f) => f, (_) => null);
      expect(
        failure,
        const ValidationFailure(
          'That pass is no longer on sale.',
          'product_unavailable',
        ),
      );
    },
  );

  test(
    'the open order is the newest unpaid one (failed payments are resumable)',
    () async {
      h.adapter.on(
        'GET',
        '/v1/orders',
        (_) => FakeReply(200, fixture('orders_page.json')),
      );
      final open = (await repo.getOpenOrder()).getOrElse(
        (f) => throw StateError(f.message),
      );
      expect(open!.id, '5e9b7c1a-2f3d-4c5b-8a7e-6d5c4b3a2f11');
      expect(open.status, OrderStatus.paymentFailed);
      expect(open.isOpen, isTrue);
    },
  );

  test(
    'open-order lookup follows cursors past a page of completed orders',
    () async {
      final page = fixtureMap('orders_page.json');
      final entries = page['items']! as List;
      h.adapter.on(
        'GET',
        '/v1/orders',
        (r) => FakeReply(
          200,
          r.uri.queryParameters['cursor'] == null
              ? {
                  'items': [entries.first],
                  'next_cursor': 'older-orders',
                }
              : {
                  'items': [entries.last],
                  'next_cursor': null,
                },
        ),
      );
      final open = (await repo.getOpenOrder()).getOrElse(
        (f) => throw StateError(f.message),
      );
      expect(open!.status, OrderStatus.paymentFailed);
      expect(
        h.adapter.requests.last.uri.queryParameters['cursor'],
        'older-orders',
      );
    },
  );

  test(
    'order total uses server cents even when the reviewed cart price differs',
    () async {
      final draft = fixtureMap('order_draft.json')
        ..['total'] = {'amount_cents': 3100, 'currency': 'ZAR'};
      h.adapter.on('POST', '/v1/orders', (_) => FakeReply(201, draft));
      final order = (await repo.createOrder(
        items: const [CartItem(plan: _pass, quantity: 2)],
      )).getOrElse((f) => throw StateError(f.message));
      expect(order.totalCents, 3100);
      expect(h.adapter.requests.single.data, {
        'lines': [
          {'product_id': _pass.id, 'quantity': 2},
        ],
      });
    },
  );

  test(
    'online payment and RICA placeholders never mutate the server',
    () async {
      expect(
        (await repo.pay(
          orderId: 'test-order',
          method: PaymentMethod.card,
        )).isLeft(),
        isTrue,
      );
      expect((await repo.markIdentityVerified('test-order')).isLeft(), isTrue);
      expect(h.adapter.requests, isEmpty);
    },
  );

  test('an unknown order is a NotFoundFailure', () async {
    h.adapter.on(
      'GET',
      '/v1/orders/nope',
      (_) =>
          FakeReply.problem(404, 'order_not_found', detail: 'Unknown order.'),
    );
    expect(
      (await repo.getOrder('nope')).match((f) => f, (_) => null),
      isA<NotFoundFailure>(),
    );
  });

  test('every server status maps to a domain status', () {
    expect(orderStatusFromApi('draft'), OrderStatus.awaitingPayment);
    expect(orderStatusFromApi('awaiting_payment'), OrderStatus.awaitingPayment);
    expect(orderStatusFromApi('failed'), OrderStatus.paymentFailed);
    expect(orderStatusFromApi('paid'), OrderStatus.paid);
    expect(orderStatusFromApi('fulfilled'), OrderStatus.paid);
    expect(orderStatusFromApi('expired'), OrderStatus.expired);
    expect(orderStatusFromApi('cancelled'), OrderStatus.cancelled);
    expect(() => orderStatusFromApi('refunded'), throwsFormatException);
  });
}
