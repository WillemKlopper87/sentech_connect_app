import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/network/auth_tokens.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_checkout_repository.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  for (final catalog in [false, true]) {
    for (final transition in [
      'logout',
      'customer',
      'tenant',
      'tenant roundtrip',
      'same customer relogin',
    ]) {
      for (final terminal in [false, true]) {
        test(
          '${catalog ? 'catalogue' : 'orders'} rejects $transition while ${terminal ? 'terminal' : 'first'} page is pending',
          () async {
            final h = ApiHarness();
            await h.signIn();
            final entered = Completer<void>();
            final release = Completer<void>();
            final path = catalog ? '/v1/products' : '/v1/orders';
            final fixtureName = catalog
                ? 'products_page_2.json'
                : 'orders_page.json';
            final firstItems = terminal
                ? [(fixtureMap(fixtureName)['items']! as List).last]
                : <Object>[];
            h.adapter.on('GET', path, (r) async {
              if (r.uri.queryParameters['cursor'] == null) {
                entered.complete();
                await release.future;
                return FakeReply(200, {
                  'items': firstItems,
                  'next_cursor': terminal ? null : 'next',
                });
              }
              return FakeReply(
                200,
                fixture(catalog ? 'products_page_2.json' : 'orders_page.json'),
              );
            });
            final pending = catalog
                ? HttpCatalogRepository(
                    h.api,
                    h.tenantContext,
                  ).getProducts().then((r) => r.isLeft())
                : HttpCheckoutRepository(
                    h.api,
                  ).getOpenOrder().then((r) => r.isLeft());
            await entered.future;
            if (transition == 'logout' ||
                transition == 'same customer relogin') {
              await h.tokens.clear();
            }
            if (transition == 'tenant' || transition == 'tenant roundtrip') {
              h.tenantContext.slug = 'other';
              if (transition == 'tenant roundtrip') {
                h.tenantContext.slug = 'sentech';
              }
            }
            if (transition == 'customer' || transition == 'tenant') {
              await h.tokens.write(
                AuthTokens(
                  accessToken: 'B-access',
                  refreshToken: 'B-refresh',
                  accessExpiresAt: h.now.add(const Duration(minutes: 15)),
                  customerId: 'customer-B',
                  tenantSlug: h.tenantContext.slug,
                ),
              );
            }
            if (transition == 'same customer relogin') {
              await h.signIn(access: 'new-session');
            }
            release.complete();
            expect(await pending, isTrue);
            expect(h.adapter.requestsTo('GET', path), hasLength(1));
            expect(
              h.adapter.requests.any(
                (r) => r.headers['Authorization'] == 'Bearer B-access',
              ),
              isFalse,
            );
          },
        );
      }
    }
  }

  test(
    'stale 401 never refreshes or expires the replacement customer',
    () async {
      final h = ApiHarness();
      await h.signIn();
      final entered = Completer<void>();
      final release = Completer<void>();
      h.adapter.on('GET', '/v1/orders', (_) async {
        entered.complete();
        await release.future;
        return FakeReply.problem(401, 'access_expired');
      });
      final pending = HttpCheckoutRepository(h.api).getOpenOrder();
      await entered.future;
      await h.tokens.write(
        AuthTokens(
          accessToken: 'B-access',
          refreshToken: 'B-refresh',
          accessExpiresAt: h.now.add(const Duration(minutes: 15)),
          customerId: 'customer-B',
          tenantSlug: 'sentech',
        ),
      );
      release.complete();
      expect((await pending).isLeft(), isTrue);
      expect(h.adapter.requestsTo('POST', '/v1/auth/token/refresh'), isEmpty);
      expect((await h.tokens.read())!.customerId, 'customer-B');
    },
  );

  test(
    'scope change during proactive refresh never sends replacement credentials',
    () async {
      final h = ApiHarness();
      await h.signIn(validFor: const Duration(seconds: 5));
      final entered = Completer<void>();
      final release = Completer<void>();
      h.adapter.on('POST', '/v1/auth/token/refresh', (_) async {
        entered.complete();
        await release.future;
        return FakeReply(200, fixture('token_pair.json'));
      });
      final pending = HttpCheckoutRepository(h.api).getOpenOrder();
      await entered.future;
      await h.tokens.clear();
      await h.tokens.write(
        AuthTokens(
          accessToken: 'B-access',
          refreshToken: 'B-refresh',
          accessExpiresAt: h.now.add(const Duration(minutes: 15)),
          customerId: 'customer-B',
          tenantSlug: 'sentech',
        ),
      );
      release.complete();
      expect((await pending).isLeft(), isTrue);
      expect(h.adapter.requestsTo('GET', '/v1/orders'), isEmpty);
      expect((await h.tokens.read())!.customerId, 'customer-B');
    },
  );

  test(
    'normal same-customer refresh between pages preserves order lookup scope',
    () async {
      final h = ApiHarness();
      await h.signIn();
      h.adapter.on(
        'POST',
        '/v1/auth/token/refresh',
        (_) => FakeReply(200, fixture('token_pair.json')),
      );
      h.adapter.on('GET', '/v1/orders', (r) {
        if (r.uri.queryParameters['cursor'] == null) {
          h.now = h.now.add(const Duration(minutes: 16));
          return const FakeReply(200, {'items': [], 'next_cursor': 'next'});
        }
        return FakeReply(200, fixture('orders_page.json'));
      });
      final order = (await HttpCheckoutRepository(
        h.api,
      ).getOpenOrder()).getOrElse((f) => throw StateError(f.message));
      expect(order, isNotNull);
      expect(
        h.adapter.requestsTo('POST', '/v1/auth/token/refresh'),
        hasLength(1),
      );
      expect(
        h.adapter.requestsTo('GET', '/v1/orders').last.headers['Authorization'],
        'Bearer access-2',
      );
    },
  );
}
