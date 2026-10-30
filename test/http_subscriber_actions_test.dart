import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/plan_change.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

Object? _body(RequestOptions r) => r.data is String ? jsonDecode(r.data! as String) : r.data;

void main() {
  const serviceId = '9a1b2c3d-3333-4a33-8a33-0000000000b5';
  const planId = '3c0d5f7a-1111-4a11-8a11-000000000003';
  const changePath = '/v1/me/subscriber/services/$serviceId/change-plan';
  const cancelPath = '/v1/me/subscriber/services/$serviceId/cancel';

  late ApiHarness h;
  late HttpSubscriberRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpSubscriberRepository(h.api);
  });

  group('change plan', () {
    test('posts only new_plan_id with the Idempotency-Key and reads an applied change with its invoice', () async {
      h.adapter.on('POST', changePath, (_) => FakeReply(200, fixture('subscriber_change_applied.json')));
      final change = _ok<PlanChange>(await repo.changePlan(serviceId, planId, idempotencyKey: 'app-change-key-1'));
      expect(change.applied, isTrue);
      expect(change.effectiveOn, DateTime.utc(2026, 11, 3));
      expect(change.prorationInvoiceId, '9a1b2c3d-4444-4a44-8a44-0000000000d1');
      final request = h.adapter.requests.single;
      expect(_body(request), {'new_plan_id': planId});
      expect(request.headers['Idempotency-Key'], 'app-change-key-1');
      expect(request.headers['Authorization'], 'Bearer access-1');
    });

    test('a scheduled change has no invoice', () async {
      h.adapter.on('POST', changePath, (_) => FakeReply(200, fixture('subscriber_change_scheduled.json')));
      final change = _ok<PlanChange>(await repo.changePlan(serviceId, planId, idempotencyKey: 'app-change-key-2'));
      expect(change.applied, isFalse);
      expect(change.effectiveOn, DateTime.utc(2026, 12, 1));
      expect(change.prorationInvoiceId, isNull);
    });

    final refusals = <(int, String, Type)>[
      (409, 'service_cancellation_scheduled', CancellationScheduledFailure),
      (409, 'service_plan_change_already_billed', PlanChangeBilledFailure),
      (409, 'service_plan_change_already_invoiced', PlanChangeBilledFailure),
      (409, 'kyc_required', KycRequiredFailure),
      (409, 'illegal_transition', ServiceStateFailure),
      (409, 'plan_kind_mismatch', PlanUnavailableFailure),
      (409, 'subscriber_plan_inactive', PlanUnavailableFailure),
      (404, 'subscriber_plan_not_found', PlanUnavailableFailure),
      (404, 'service_not_found', NotFoundFailure),
      (403, 'module_not_enabled', ModuleDisabledFailure),
      (409, 'feature_disabled', FeatureDisabledFailure),
    ];
    for (final (status, code, type) in refusals) {
      test('$status $code is a $type', () async {
        h.adapter.on('POST', changePath, (_) => FakeReply.problem(status, code));
        expect(_failure(await repo.changePlan(serviceId, planId, idempotencyKey: 'app-change-key-3')).runtimeType, type);
      });
    }

    test('offline is a NetworkFailure', () async {
      h.adapter.on('POST', changePath, (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.changePlan(serviceId, planId, idempotencyKey: 'app-change-key-4')), isA<NetworkFailure>());
    });

    test('a malformed answer is refused, not guessed', () async {
      h.adapter.on('POST', changePath, (_) => const FakeReply(200, {'applied': true, 'effective_on': 'soon', 'proration_invoice_id': null}));
      expect(_failure(await repo.changePlan(serviceId, planId, idempotencyKey: 'app-change-key-5')), isA<ServerFailure>());
    });
  });

  group('cancel', () {
    test('posts only the reason with the Idempotency-Key and reads the service with its end date', () async {
      h.adapter.on('POST', cancelPath, (_) => FakeReply(200, fixture('subscriber_service_cancel_scheduled.json')));
      final service = _ok<SubscriberService>(await repo.cancel(serviceId, 'Moving', idempotencyKey: 'app-cancel-key-1'));
      expect(service.cancelEffectiveOn, DateTime.utc(2026, 11, 30));
      expect(service.status, ServiceStatus.active);
      expect(service.isCancellationScheduled, isTrue);
      final request = h.adapter.requests.single;
      expect(_body(request), {'reason': 'Moving'});
      expect(request.headers['Idempotency-Key'], 'app-cancel-key-1');
    });

    final refusals = <(int, String, Type)>[
      (409, 'pending_requires_immediate_cancellation', PendingCancelFailure),
      (409, 'illegal_transition', ServiceStateFailure),
      (404, 'service_not_found', NotFoundFailure),
      (403, 'tenant_suspended', ProviderUnavailableFailure),
      (429, 'rate_limited', RateLimitedFailure),
    ];
    for (final (status, code, type) in refusals) {
      test('$status $code is a $type', () async {
        h.adapter.on('POST', cancelPath, (_) => FakeReply.problem(status, code));
        expect(_failure(await repo.cancel(serviceId, 'Moving', idempotencyKey: 'app-cancel-key-2')).runtimeType, type);
      });
    }

    test('offline is a NetworkFailure', () async {
      h.adapter.on('POST', cancelPath, (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await repo.cancel(serviceId, 'Moving', idempotencyKey: 'app-cancel-key-3')), isA<NetworkFailure>());
    });
  });
}
