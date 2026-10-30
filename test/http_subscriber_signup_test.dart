import 'package:dio/dio.dart' show DioExceptionType;
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/http_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_plans_repository.dart';
import 'package:sentech_connect_app/features/subscriber/data/repositories/mock_subscriber_repository.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_signup.dart';

import 'helpers/api_harness.dart';
import 'helpers/fake_http_adapter.dart';
import 'helpers/fixtures.dart';

const _path = '/v1/me/subscriber/signup';
const _plan = '3c0d5f7a-1111-4a11-8a11-000000000002';

Failure? _failure<T>(Either<Failure, T> e) => e.match((f) => f, (_) => null);

void main() {
  late ApiHarness h;
  late HttpSubscriberRepository repo;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    repo = HttpSubscriberRepository(h.api);
  });

  Future<Either<Failure, SubscriberSignup>> signup({String? address, String key = 'app-signup-key-1'}) =>
      repo.signup(planId: _plan, termsVersion: '2026-09-30', idempotencyKey: key, installAddress: address);

  group('HttpSubscriberRepository.signup', () {
    test('posts the body with the Idempotency-Key and reads the pending service and first invoice', () async {
      h.adapter.on('POST', _path, (_) => FakeReply(201, fixture('subscriber_signup.json')));
      final result = (await signup(address: '1 Main Road')).getOrElse((f) => throw f);
      expect(result.service.status, ServiceStatus.pending);
      expect(result.service.activationBlocker, ActivationBlocker.firstInvoiceUnpaid);
      expect(result.invoice.kind, 'initial');
      expect(result.invoice.amountCents, 109900);
      final request = h.adapter.requests.single;
      expect(request.headers['Idempotency-Key'], 'app-signup-key-1');
      expect(request.headers['Authorization'], 'Bearer access-1');
      expect(request.data, {'plan_id': _plan, 'accept_terms_version': '2026-09-30', 'install_address': '1 Main Road'});
    });

    test('a recurring plan sends no install_address and never a term_months', () async {
      h.adapter.on('POST', _path, (_) => FakeReply(201, fixture('subscriber_signup.json')));
      await signup();
      final body = h.adapter.requests.single.data as Map;
      expect(body.keys, unorderedEquals(['plan_id', 'accept_terms_version']));
    });

    test('there is no human check on the route', () async {
      h.adapter.on('POST', _path, (_) => FakeReply(201, fixture('subscriber_signup.json')));
      await signup();
      expect(h.adapter.requests.single.headers.keys.map((k) => k.toLowerCase()), isNot(contains('x-human-token')));
    });

    test('a replay with the same key answers the same pair', () async {
      h.adapter.on('POST', _path, (_) => FakeReply(201, fixture('subscriber_signup.json'), const {'idempotent-replayed': ['true']}));
      final first = (await signup()).getOrElse((f) => throw f);
      final second = (await signup()).getOrElse((f) => throw f);
      expect(second, first);
    });

    test('every refusal the platform can send maps to its typed failure', () async {
      final cases = <(int, String, Matcher)>[
        (422, 'consent_version_outdated', isA<ConsentVersionOutdatedFailure>()),
        (404, 'subscriber_plan_not_found', isA<PlanUnavailableFailure>()),
        (409, 'subscriber_plan_inactive', isA<PlanUnavailableFailure>()),
        (409, 'subscriber_version_unavailable', isA<PlanUnavailableFailure>()),
        (409, 'account_closed', isA<ServiceStateFailure>()),
        (422, 'subscriber_profile_invalid', isA<SubscriberProfileInvalidFailure>()),
        (409, 'customer_link_required', isA<CustomerLinkRequiredFailure>()),
        (403, 'module_not_enabled', isA<ModuleDisabledFailure>()),
        (409, 'feature_disabled', isA<FeatureDisabledFailure>()),
        (403, 'tenant_suspended', isA<ProviderUnavailableFailure>()),
        (503, 'service_number_unavailable', isA<ServerFailure>()),
        (429, 'rate_limited', isA<RateLimitedFailure>()),
      ];
      for (final (status, code, matcher) in cases) {
        // A fresh client per case: a 5xx makes the client re-check the session.
        final fresh = ApiHarness();
        await fresh.signIn();
        fresh.adapter.on('POST', _path, (_) => FakeReply.problem(status, code));
        final result = await HttpSubscriberRepository(
          fresh.api,
        ).signup(planId: _plan, termsVersion: '2026-09-30', idempotencyKey: 'app-signup-key-1');
        expect(_failure(result), matcher, reason: code);
      }
    });

    test('offline is a NetworkFailure', () async {
      h.adapter.on('POST', _path, (_) => const FakeReply.error(DioExceptionType.connectionError));
      expect(_failure(await signup()), isA<NetworkFailure>());
    });
  });

  group('MockSubscriberRepository.signup', () {
    test('creates a pending service that the list and detail then show; the same key replays', () async {
      final mock = MockSubscriberRepository();
      final plan = MockSubscriberPlansRepository.mockPlans.last;
      final first = (await mock.signup(planId: plan.id, termsVersion: '2026-09-30', idempotencyKey: 'k1')).getOrElse((f) => throw f);
      final again = (await mock.signup(planId: plan.id, termsVersion: '2026-09-30', idempotencyKey: 'k1')).getOrElse((f) => throw f);
      expect(again, first);
      expect(first.service.status, ServiceStatus.pending);
      final list = (await mock.listServices()).getOrElse((f) => throw f);
      expect(list.first.id, first.service.id);
      expect(list, hasLength(2));
      expect((await mock.getService(first.service.id)).isRight(), isTrue);
    });

    test('an unknown plan is PlanUnavailableFailure', () async {
      final result = await MockSubscriberRepository().signup(planId: 'nope', termsVersion: '2026-09-30', idempotencyKey: 'k');
      expect(_failure(result), isA<PlanUnavailableFailure>());
    });
  });
}
