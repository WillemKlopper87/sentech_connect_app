import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/wifi_voucher/data/repositories/http_wifi_hotspots_repository.dart';
import 'package:sentech_connect_app/features/wifi_voucher/domain/entities/wifi_hotspot.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

void main() {
  late ApiHarness h;
  late HttpWifiHotspotsRepository repo;

  setUp(() {
    h = ApiHarness();
    repo = HttpWifiHotspotsRepository(h.api, h.tenantContext);
  });

  test('maps the public page: coordinates, status and optional address', () async {
    h.adapter.on('GET', '/v1/hotspots', (_) => FakeReply(200, fixture('hotspots_page.json')));
    final spots = (await repo.getHotspots()).getOrElse((f) => throw StateError(f.message));

    expect(spots, hasLength(2));
    expect(spots.first.name, 'eMbalenhle Community Hall');
    expect(spots.first.latitude, -26.6873);
    expect(spots.first.longitude, 29.0721);
    expect(spots.first.status, HotspotStatus.live);
    expect(spots.first.address, 'Main Road, eMbalenhle');
    expect(spots.last.status, HotspotStatus.maintenance);
    expect(spots.last.isUnderMaintenance, isTrue);
    expect(spots.last.address, isNull);
  });

  test('is public and scoped to the tenant', () async {
    h.adapter.on('GET', '/v1/hotspots', (_) => FakeReply(200, fixture('hotspots_page.json')));
    await repo.getHotspots();
    final request = h.adapter.requests.single;
    expect(request.uri.queryParameters['tenant'], 'sentech');
    expect(request.headers.containsKey('Authorization'), isFalse);
  });

  test('follows the cursor across pages', () async {
    final items = fixtureMap('hotspots_page.json')['items']! as List;
    h.adapter.on('GET', '/v1/hotspots', (r) {
      final cursor = r.uri.queryParameters['cursor'];
      return FakeReply(200, {
        'items': [cursor == null ? items.first : items.last],
        'next_cursor': cursor == null ? 'abc' : null,
      });
    });
    final spots = (await repo.getHotspots()).getOrElse((f) => throw StateError(f.message));
    expect(spots.map((s) => s.name), ['eMbalenhle Community Hall', 'Secunda Library']);
    expect(h.adapter.requests[1].uri.queryParameters['cursor'], 'abc');
  });

  test('a cursor that repeats stops with a failure instead of looping', () async {
    h.adapter.on('GET', '/v1/hotspots', (_) => const FakeReply(200, {'items': <Object>[], 'next_cursor': 'same'}));
    expect((await repo.getHotspots()).match((f) => f, (_) => null), isA<ServerFailure>());
  });

  test('an empty list is a success with no hotspots', () async {
    h.adapter.on('GET', '/v1/hotspots', (_) => const FakeReply(200, {'items': <Object>[], 'next_cursor': null}));
    expect((await repo.getHotspots()).getOrElse((_) => throw StateError('failed')), isEmpty);
  });

  test('offline is a NetworkFailure', () async {
    h.adapter.on('GET', '/v1/hotspots', (_) => const FakeReply.error(DioExceptionType.connectionError));
    expect((await repo.getHotspots()).match((f) => f, (_) => null), isA<NetworkFailure>());
  });

  test('a server error is a failure, not an empty list', () async {
    h.adapter.on('GET', '/v1/hotspots', (_) => FakeReply.problem(503, 'service_unavailable'));
    expect((await repo.getHotspots()).isLeft(), isTrue);
  });

  test('an unknown status is refused rather than shown as working', () {
    expect(
      () => hotspotFromJson({
        ...Map<String, Object?>.from((fixtureMap('hotspots_page.json')['items']! as List).first as Map),
        'status': 'retired',
      }),
      throwsFormatException,
    );
  });
}
