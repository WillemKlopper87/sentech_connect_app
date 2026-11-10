import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart' hide Order;
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/order.dart';
import 'package:sentech_connect_app/features/fiveg_service/data/http_fiveg_repository.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';

import '../helpers/api_harness.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

const _service = 'a6b4c2d0-1111-4a22-8b33-00000000c001';
const _dataPath = '/v1/me/subscriber/services/$_service/data';
const _unlockPath = '$_dataPath/unlock-orders';

void main() {
  late ApiHarness h;
  late HttpFiveGRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpFiveGRepository(h.api);
  });

  group('getUsage', () {
    test('reads the data route with the bearer token and decodes the allowance', () async {
      h.adapter.on('GET', _dataPath, (_) => FakeReply(200, fixture('fiveg_usage_normal.json')));
      final usage = _ok(await repo.getUsage(_service));
      expect(usage.state, UsageState.normal);
      expect(usage.usedPercent, 20);
      expect(h.adapter.requests.single.headers['Authorization'], 'Bearer access-1');
    });

    test('a 404 means the feature is not available for this service', () async {
      h.adapter.on('GET', _dataPath, (_) => FakeReply.problem(404, 'not_found', title: 'Not Found'));
      expect(_failure(await repo.getUsage(_service)), isA<FiveGNotAvailableFailure>());
    });

    test('a server error stays a server failure, not a hidden feature', () async {
      h.adapter.on('GET', _dataPath, (_) => FakeReply.problem(500, 'internal'));
      expect(_failure(await repo.getUsage(_service)), isA<ServerFailure>());
    });

    test('an unknown plan kind is refused by the decoder (a server failure)', () async {
      final body = {...fixtureMap('fiveg_usage_normal.json'), 'plan_kind': 'unlimited'};
      h.adapter.on('GET', _dataPath, (_) => FakeReply(200, body));
      expect(_failure(await repo.getUsage(_service)), isA<ServerFailure>());
    });
  });

  group('createUnlockOrder', () {
    test('posts the product code with an Idempotency-Key and returns a data-unlock order', () async {
      h.adapter.on('POST', _unlockPath, (_) => FakeReply(201, fixture('fiveg_unlock_order.json')));
      final order = _ok(await repo.createUnlockOrder(
        _service,
        productCode: 'data_unlock_50gb',
        idempotencyKey: 'app-key-0000001',
      ));
      expect(order.kind, OrderKind.dataUnlock);
      expect(order.isHotspotPass, isFalse);
      final request = h.adapter.requestsTo('POST', _unlockPath).single;
      expect(request.data, {'product_code': 'data_unlock_50gb'});
      expect(request.headers['Idempotency-Key'], 'app-key-0000001');
      expect(request.headers['Authorization'], 'Bearer access-1');
    });

    test('the typed refusals keep their codes', () async {
      for (final code in ['unlock_not_available', 'unlock_limit_reached', 'unlock_order_open', 'unlock_service_inactive']) {
        h.adapter.on('POST', _unlockPath, (_) => FakeReply.problem(409, code));
        final failure = _failure(await repo.createUnlockOrder(_service, productCode: 'x', idempotencyKey: 'key-00000001'));
        expect(failure, isA<ValidationFailure>(), reason: code);
        expect((failure! as ValidationFailure).code, code, reason: code);
      }
    });

    test('unlock_not_available is typed on a 422 (unlock-order POST) as well as on a 409', () async {
      h.adapter.on('POST', _unlockPath, (_) => FakeReply.problem(422, 'unlock_not_available'));
      expect(
        _failure(await repo.createUnlockOrder(_service, productCode: 'x', idempotencyKey: 'key-00000001')),
        isA<UnlockNotAvailableFailure>(),
      );
    });

    test('idempotency_in_progress (409) is its own friendly failure, not a generic error', () async {
      h.adapter.on('POST', _unlockPath, (_) => FakeReply.problem(409, 'idempotency_in_progress'));
      expect(
        _failure(await repo.createUnlockOrder(_service, productCode: 'x', idempotencyKey: 'key-00000001')),
        isA<IdempotencyInProgressFailure>(),
      );
    });

    test('unlock_payment_held (409) is typed', () async {
      h.adapter.on('POST', _unlockPath, (_) => FakeReply.problem(409, 'unlock_payment_held'));
      expect(
        _failure(await repo.createUnlockOrder(_service, productCode: 'x', idempotencyKey: 'key-00000001')),
        isA<UnlockPaymentHeldFailure>(),
      );
    });

    test('a 404 on the unlock route is a feature that is not available', () async {
      h.adapter.on('POST', _unlockPath, (_) => FakeReply.problem(404, 'not_found'));
      expect(
        _failure(await repo.createUnlockOrder(_service, productCode: 'x', idempotencyKey: 'key-00000001')),
        isA<FiveGNotAvailableFailure>(),
      );
    });
  });
}
