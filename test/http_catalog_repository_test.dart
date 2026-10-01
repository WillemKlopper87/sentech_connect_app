import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/data/repositories/http_catalog_repository.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/plan.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  late ApiHarness h;
  late HttpCatalogRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpCatalogRepository(h.api, h.tenantContext);
  });

  test(
    'follows the cursor across pages and maps passes to integer-cent plans',
    () async {
      h.adapter.on('GET', '/v1/products', (r) {
        return FakeReply(
          200,
          fixture(
            r.uri.queryParameters['cursor'] == null
                ? 'products_page_1.json'
                : 'products_page_2.json',
          ),
        );
      });
      final plans = (await repo.getProducts()).getOrElse(
        (f) => throw StateError(f.message),
      );

      expect(plans.map((p) => p.name), [
        '1 Hour Pass',
        'Day Pass',
        'Week Pass',
      ]);
      expect(plans.first.priceCents, 1500);
      expect(plans.first.category, ProductCategory.hotspotPass);
      expect(plans.first.dataDescription, '1 GB · 1 hour');
      expect(plans.first.speedMbps, 10);
      expect(plans[1].speedMbps, 0);
      expect(plans[2].dataDescription, 'Unlimited data · 7 days');

      final first = h.adapter.requests.first.uri.queryParameters;
      expect(first['tenant'], 'sentech');
      expect(
        h.adapter.requests[1].uri.queryParameters['cursor'],
        'WzEsIjBiMGMiXQ',
      );
      expect(
        h.adapter.requests.every(
          (r) => !r.headers.containsKey('Authorization'),
        ),
        isTrue,
      );
    },
  );

  test('offline is a NetworkFailure the catalogue can retry', () async {
    h.adapter.on(
      'GET',
      '/v1/products',
      (_) => const FakeReply.error(DioExceptionType.connectionError),
    );
    expect(
      (await repo.getProducts()).match((f) => f, (_) => null),
      isA<NetworkFailure>(),
    );
  });

  test('a non-ZAR price is refused rather than shown wrongly', () async {
    final page = fixtureMap('products_page_2.json');
    final item = Map<String, Object?>.from(
      (page['items']! as List).first as Map,
    )..['price'] = {'amount_cents': 100, 'currency': 'USD'};
    h.adapter.on(
      'GET',
      '/v1/products',
      (_) => FakeReply(200, {
        'items': [item],
        'next_cursor': null,
      }),
    );
    expect(
      (await repo.getProducts()).match((f) => f, (_) => null),
      isA<ServerFailure>(),
    );
  });

  test(
    'repeated cursors fail instead of silently presenting partial catalogue',
    () async {
      h.adapter.on(
        'GET',
        '/v1/products',
        (_) => const FakeReply(200, {'items': [], 'next_cursor': 'repeat'}),
      );
      expect(
        (await repo.getProducts()).match((f) => f, (_) => null),
        isA<ServerFailure>(),
      );
      expect(
        h.adapter.requests.length,
        lessThanOrEqualTo(HttpCatalogRepository.maxPages),
      );
    },
  );

  test('pass descriptions', () {
    expect(describePass(durationMinutes: 60, dataMb: 1024), '1 GB · 1 hour');
    expect(describePass(durationMinutes: 1440, dataMb: 5120), '5 GB · 1 day');
    expect(
      describePass(durationMinutes: 120, dataMb: 1536),
      '1.5 GB · 2 hours',
    );
    expect(describePass(durationMinutes: 30, dataMb: 500), '500 MB · 30 min');
    expect(
      describePass(durationMinutes: 10080, dataMb: null),
      'Unlimited data · 7 days',
    );
  });
}
