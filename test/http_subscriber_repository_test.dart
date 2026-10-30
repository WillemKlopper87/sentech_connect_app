import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/time/api_date.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_account.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_plan.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

Map<String, Object?> _service(int index, [Map<String, Object?> override = const {}]) => {
  ...Map<String, Object?>.from((fixtureMap('subscriber_services_page.json')['items']! as List)[index] as Map),
  ...override,
};

void main() {
  late ApiHarness h;
  late HttpSubscriberPlansRepository plans;
  late HttpSubscriberRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    plans = HttpSubscriberPlansRepository(h.api, h.tenantContext);
    repo = HttpSubscriberRepository(h.api);
  });

  group('plans', () {
    test('maps both kinds, price, setup fee, speeds and optional fair-use fields', () async {
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => FakeReply(200, fixture('subscriber_plans_page.json')));
      final list = _ok(await plans.list());
      expect(list, hasLength(2));
      final hotspot = list.first;
      expect(hotspot.kind, SubscriberPlanKind.recurringHotspot);
      expect(hotspot.priceCents, 19900);
      expect(hotspot.kycRequired, isFalse);
      expect(hotspot.fupBytes, 214748364800);
      expect(hotspot.burstDownKbps, isNull);
      final air = list.last;
      expect(air.kind, SubscriberPlanKind.fixedWireless);
      expect(air.setupFeeCents, 99900);
      expect(air.kycRequired, isTrue);
      expect(air.burstSeconds, 30);
      expect(air.fupBytes, isNull);
    });

    test('is public and always sends the tenant slug', () async {
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => FakeReply(200, fixture('subscriber_plans_page.json')));
      await plans.list();
      final request = h.adapter.requests.single;
      expect(request.uri.queryParameters['tenant'], 'sentech');
      expect(request.headers.containsKey('Authorization'), isFalse);
    });

    test('follows the cursor across two pages', () async {
      final items = fixtureMap('subscriber_plans_page.json')['items']! as List;
      h.adapter.on('GET', '/v1/subscriber-plans', (r) {
        final cursor = r.uri.queryParameters['cursor'];
        return FakeReply(200, {
          'items': [cursor == null ? items.first : items.last],
          'next_cursor': cursor == null ? 'p2' : null,
        });
      });
      final list = _ok(await plans.list());
      expect(list.map((p) => p.code), ['HOME-HOTSPOT-10', 'AIR-50']);
      expect(h.adapter.requests[1].uri.queryParameters['cursor'], 'p2');
    });

    test('a repeated cursor stops with a failure instead of looping', () async {
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => const FakeReply(200, {'items': <Object>[], 'next_cursor': 'same'}));
      expect(_failure(await plans.list()), isA<ServerFailure>());
    });

    test('module off is ModuleDisabledFailure; feature off is FeatureDisabledFailure', () async {
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => FakeReply.problem(403, 'module_not_enabled'));
      expect(_failure(await plans.list()), isA<ModuleDisabledFailure>());
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => FakeReply.problem(409, 'feature_disabled'));
      expect(_failure(await plans.list()), isA<FeatureDisabledFailure>());
    });

    test('an unknown plan kind is refused', () async {
      final first = Map<String, Object?>.from((fixtureMap('subscriber_plans_page.json')['items']! as List).first as Map);
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => FakeReply(200, {'items': [{...first, 'kind': 'satellite'}], 'next_cursor': null}));
      expect(_failure(await plans.list()), isA<ServerFailure>());
    });

    test('a currency other than ZAR is refused', () async {
      final first = Map<String, Object?>.from((fixtureMap('subscriber_plans_page.json')['items']! as List).first as Map);
      final bad = {...first, 'price': {'amount_cents': 100, 'currency': 'USD'}};
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => FakeReply(200, {'items': [bad], 'next_cursor': null}));
      expect(_failure(await plans.list()), isA<ServerFailure>());
    });

    test('offline is a NetworkFailure', () async {
      h.adapter.on('GET', '/v1/subscriber-plans', (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await plans.list()), isA<NetworkFailure>());
    });
  });

  group('account', () {
    test('maps the account, profile and service counts', () async {
      h.adapter.on('GET', '/v1/me/subscriber', (_) => FakeReply(200, fixture('subscriber_account.json')));
      final account = _ok<SubscriberAccount?>(await repo.getAccount())!;
      expect(account.accountNo, 'AC-000101');
      expect(account.kind, SubscriberAccountKind.individual);
      expect(account.status, SubscriberAccountStatus.active);
      expect(account.isClosed, isFalse);
      expect(account.serviceCounts.total, 4);
      expect(account.serviceCounts.suspended, 1);
      expect(account.profile!.displayName, 'Thandi Mokoena');
      expect(account.profile!.language, 'zu');
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('404 subscriber_not_found is no account, not an error', () async {
      h.adapter.on('GET', '/v1/me/subscriber', (_) => FakeReply.problem(404, 'subscriber_not_found'));
      expect(_ok<SubscriberAccount?>(await repo.getAccount()), isNull);
    });

    test('a null profile and missing counts are tolerated', () async {
      h.adapter.on('GET', '/v1/me/subscriber', (_) => FakeReply(200, {
            ...fixtureMap('subscriber_account.json'),
            'profile': null,
            'service_counts': <String, Object?>{},
            'status': 'closed',
          }));
      final account = _ok<SubscriberAccount?>(await repo.getAccount())!;
      expect(account.profile, isNull);
      expect(account.serviceCounts.total, 0);
      expect(account.isClosed, isTrue);
    });

    test('an unknown account status is refused', () async {
      h.adapter.on('GET', '/v1/me/subscriber', (_) => FakeReply(200, {...fixtureMap('subscriber_account.json'), 'status': 'frozen'}));
      expect(_failure(await repo.getAccount()), isA<ServerFailure>());
    });

    test('other failures still fail (module off)', () async {
      h.adapter.on('GET', '/v1/me/subscriber', (_) => FakeReply.problem(403, 'module_not_enabled'));
      expect(_failure(await repo.getAccount()), isA<ModuleDisabledFailure>());
    });
  });

  group('services', () {
    test('maps every status with plan facts, blocker, scheduled cancel and scheduled plan change', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply(200, fixture('subscriber_services_page.json')));
      final list = _ok(await repo.listServices());
      expect(list.map((s) => s.status), [
        ServiceStatus.pending,
        ServiceStatus.active,
        ServiceStatus.suspended,
        ServiceStatus.cancelled,
      ]);
      final pending = list[0];
      expect(pending.planName, 'Home Air 50');
      expect(pending.kind, SubscriberPlanKind.fixedWireless);
      expect(pending.priceCents, 59900);
      expect(pending.downKbps, 50000);
      expect(pending.activationBlocker, ActivationBlocker.firstInvoiceUnpaid);
      expect(pending.paidThrough, isNull);
      final active = list[1];
      expect(active.activationBlocker, isNull);
      expect(active.cancelEffectiveOn, parseApiDate('2026-11-30'));
      expect(active.isCancellationScheduled, isTrue);
      expect(active.pendingPlanId, '3c0d5f7a-1111-4a11-8a11-000000000003');
      expect(active.pendingPlanName, 'Home Hotspot 5');
      expect(active.planChangeOn, parseApiDate('2026-11-01'));
      expect(active.hasPlanChangePending, isTrue);
      expect(active.activatedAt, DateTime.utc(2026, 9, 1, 7));
      final suspended = list[2];
      expect(suspended.suspendReason, SuspendReason.nonPayment);
      expect(suspended.paidThrough, parseApiDate('2026-09-30'));
      expect(list[3].cancelledAt, DateTime.utc(2026, 6, 30, 22));
    });

    test('keeps the order the API sends (newest first) and asks for 50 per page', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply(200, fixture('subscriber_services_page.json')));
      final list = _ok(await repo.listServices());
      expect(list.map((s) => s.serviceNo), ['SV-000104', 'SV-000103', 'SV-000102', 'SV-000101']);
      expect(h.adapter.requests.single.uri.queryParameters['limit'], '50');
    });

    test('follows next_cursor as the after parameter', () async {
      final items = fixtureMap('subscriber_services_page.json')['items']! as List;
      h.adapter.on('GET', '/v1/me/subscriber/services', (r) {
        final after = r.uri.queryParameters['after'];
        return FakeReply(200, {
          'items': after == null ? items.take(2).toList() : items.skip(2).toList(),
          'next_cursor': after == null ? '9a1b2c3d-3333-4a33-8a33-0000000000b2' : null,
        });
      });
      final list = _ok(await repo.listServices());
      expect(list, hasLength(4));
      expect(h.adapter.requests[1].uri.queryParameters['after'], '9a1b2c3d-3333-4a33-8a33-0000000000b2');
      expect(h.adapter.requests[1].uri.queryParameters.containsKey('cursor'), isFalse);
    });

    test('stops after five pages with a failure', () async {
      var n = 0;
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply(200, {'items': <Object>[], 'next_cursor': 'c${n++}'}));
      expect(_failure(await repo.listServices()), isA<ServerFailure>());
      expect(h.adapter.requests, hasLength(HttpSubscriberRepository.maxPages));
    });

    test('no account means no services', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply.problem(404, 'subscriber_not_found'));
      expect(_ok(await repo.listServices()), isEmpty);
    });

    test('an unknown cursor (400 invalid_cursor) is a refusal, not an empty list', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply.problem(400, 'invalid_cursor', detail: 'Unknown cursor.'));
      final f = _failure(await repo.listServices());
      expect(f, isA<ValidationFailure>());
      expect((f! as ValidationFailure).code, 'invalid_cursor');
    });

    test('an unknown service status is refused rather than guessed', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply(200, {'items': [_service(0, {'status': 'frozen'})], 'next_cursor': null}));
      expect(_failure(await repo.listServices()), isA<ServerFailure>());
    });

    test('an unknown activation blocker still loads and reads as unknown', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply(200, {'items': [_service(0, {'activation_blocker': 'something_new'})], 'next_cursor': null}));
      final list = _ok(await repo.listServices());
      expect(list.single.activationBlocker, ActivationBlocker.unknown);
    });

    test('a date-time where a date belongs is refused', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services', (_) => FakeReply(200, {'items': [_service(1, {'paid_through': '2026-11-30T00:00:00Z'})], 'next_cursor': null}));
      expect(_failure(await repo.listServices()), isA<ServerFailure>());
    });

    test('getService reads one service by id', () async {
      final item = _service(1);
      h.adapter.on('GET', '/v1/me/subscriber/services/${item['id']}', (_) => FakeReply(200, item));
      final s = _ok(await repo.getService(item['id']! as String));
      expect(s.serviceNo, 'SV-000103');
    });

    test('404 service_not_found is a NotFoundFailure', () async {
      h.adapter.on('GET', '/v1/me/subscriber/services/x', (_) => FakeReply.problem(404, 'service_not_found'));
      expect(_failure(await repo.getService('x')), isA<NotFoundFailure>());
    });
  });
}
