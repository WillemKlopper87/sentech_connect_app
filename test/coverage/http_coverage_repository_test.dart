import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/security/human_check_config.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/features/coverage/data/http_coverage_repository.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/coverage_check.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/geocode_match.dart';
import 'package:sentech_connect_app/features/coverage/domain/entities/lead.dart';

import '../helpers/api_harness.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError(f.message));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

class _Token implements HumanCheckProvider {
  _Token(this.value);
  String? value;
  Object? throwing;
  int calls = 0;

  @override
  Future<String?> token() async {
    calls++;
    final error = throwing;
    if (error != null) throw error;
    return value;
  }
}

NotifyRequest _request({bool arrival = false}) => NotifyRequest(
  contactType: ContactKind.phone,
  contactValue: '082 123 4567',
  addressText: '12 Lifalethu Avenue, eMbalenhle',
  lat: -26.51423,
  lon: 29.10311,
  technologyInterest: TechnologyInterest.any,
  waitlistConsentVersion: '2026-10-01',
  arrivalConsentGranted: arrival,
  arrivalConsentVersion: '2026-11-18',
);

void main() {
  late ApiHarness h;
  late _Token human;
  late HttpCoverageRepository repo;
  var clock = DateTime.utc(2026, 11, 26, 10);

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    human = _Token('turnstile-token-1');
    clock = DateTime.utc(2026, 11, 26, 10);
    repo = HttpCoverageRepository(h.api, tenant: h.tenantContext, humanCheck: human, now: () => clock);
    h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply(200, fixture('coverage_check_two_options.json')));
    h.adapter.on('GET', '/v1/coverage/meta', (_) => FakeReply(200, fixture('coverage_meta.json')));
    h.adapter.on('GET', '/v1/coverage/capabilities', (_) => FakeReply(200, fixture('coverage_capabilities.json')));
    h.adapter.on('POST', '/v1/coverage/address', (_) => FakeReply(200, fixture('coverage_address.json')));
    h.adapter.on('GET', '/v1/geocode/search', (_) => FakeReply(200, fixture('geocode_search.json')));
    h.adapter.on('POST', '/v1/leads', (_) => FakeReply(202, fixture('lead_accepted.json')));
    h.adapter.on('POST', '/v1/leads/withdrawal-requests', (_) => FakeReply(202, fixture('withdrawal_requested.json')));
  });

  group('check', () {
    test('check_sends_lat_lon_and_tenant', () async {
      final check = _ok(await repo.check(lat: -26.514231234, lon: 29.103119876));
      expect(check.options, hasLength(2));
      final request = h.adapter.requestsTo('GET', '/v1/coverage/check').single;
      expect(request.uri.queryParameters['tenant'], 'sentech');
      // Rounded to the 5 decimals the server quantises to (about 1 m): no more precision leaves the device than the answer needs.
      expect(request.uri.queryParameters['lat'], '-26.51423');
      expect(request.uri.queryParameters['lon'], '29.10312');
      expect(request.headers.containsKey('Authorization'), isFalse, reason: 'a public route: no session is sent');
    });

    test('a reseller tenant is sent as the tenant parameter', () async {
      h.tenantContext.slug = 'acme-isp';
      await repo.check(lat: -26.1, lon: 28.1);
      expect(h.adapter.requestsTo('GET', '/v1/coverage/check').single.uri.queryParameters['tenant'], 'acme-isp');
    });

    test('a_429_carries_retry_after', () async {
      h.adapter.on(
        'GET',
        '/v1/coverage/check',
        (_) => FakeReply.problem(429, 'rate_limited', headers: {'retry-after': ['42']}),
      );
      final failure = _failure(await repo.check(lat: -26.1, lon: 28.1));
      expect(failure, isA<RateLimitedFailure>());
      expect((failure! as RateLimitedFailure).retryAfter, const Duration(seconds: 42));
    });

    test('an_older_server_without_the_route_maps_to_unavailable_not_a_crash', () async {
      h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply.problem(404, 'http_404', title: 'Not Found'));
      expect(_failure(await repo.check(lat: -26.1, lon: 28.1)), isA<CoverageUnavailableFailure>());
      // A bare 404 with no problem body (a gateway) reads the same way.
      h.adapter.on('GET', '/v1/coverage/check', (_) => const FakeReply(404, 'Not found'));
      expect(_failure(await repo.check(lat: -26.1, lon: 28.1)), isA<CoverageUnavailableFailure>());
    });

    test('a point the server calls outside the service area, or swapped, is its own refusal', () async {
      for (final code in ['outside_service_area', 'coordinates_swapped']) {
        h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply.problem(422, code));
        expect(_failure(await repo.check(lat: -26.1, lon: 28.1)), isA<OutsideServiceAreaFailure>(), reason: code);
      }
    });

    test('timeouts and a lost network are a network failure, a 5xx is a server failure, an unreadable body is not a crash', () async {
      h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply.error(DioExceptionType.receiveTimeout));
      expect(_failure(await repo.check(lat: -26.1, lon: 28.1)), isA<NetworkFailure>());
      h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply.problem(503, 'db_unavailable'));
      expect(_failure(await repo.check(lat: -26.1, lon: 28.1)), isA<ServerFailure>());
      h.adapter.on('GET', '/v1/coverage/check', (_) => const FakeReply(200, ['not', 'an', 'object']));
      expect(_failure(await repo.check(lat: -26.1, lon: 28.1)), isA<ServerFailure>());
    });
  });

  group('meta', () {
    test('meta_is_cached_per_session_and_refreshed_on_version_change', () async {
      final first = _ok(await repo.meta());
      expect(first.datasetVersion, 7);
      await repo.meta();
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta'), hasLength(1), reason: 'the second read is the cache');
      // A check answered from another dataset version means the cached meta is stale: it is read again.
      h.adapter.on(
        'GET',
        '/v1/coverage/check',
        (_) => FakeReply(200, {...fixtureMap('coverage_check_two_options.json'), 'dataset_version': 8}),
      );
      await repo.check(lat: -26.1, lon: 28.1);
      await repo.meta();
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta'), hasLength(2));
      // The same version changes nothing.
      h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply(200, fixture('coverage_check_two_options.json')));
      h.adapter.on('GET', '/v1/coverage/meta', (_) => FakeReply(200, {...fixtureMap('coverage_meta.json'), 'dataset_version': 8}));
      await repo.meta(refresh: true);
      await repo.check(lat: -26.1, lon: 28.1); // answered from version 7 now: stale again
      await repo.meta();
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta'), hasLength(4));
    });

    test('the cache also expires after ten minutes (a consent text can change) and is per provider', () async {
      await repo.meta();
      clock = clock.add(const Duration(minutes: 9));
      await repo.meta();
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta'), hasLength(1));
      clock = clock.add(const Duration(minutes: 2));
      await repo.meta();
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta'), hasLength(2));
      h.tenantContext.slug = 'acme-isp';
      await repo.meta();
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta'), hasLength(3), reason: 'another provider has its own meta');
      expect(h.adapter.requestsTo('GET', '/v1/coverage/meta').last.uri.queryParameters['tenant'], 'acme-isp');
    });

    test('a failed read is not cached', () async {
      h.adapter.on('GET', '/v1/coverage/meta', (_) => FakeReply.problem(404, 'http_404', title: 'Not Found'));
      expect(_failure(await repo.meta()), isA<CoverageUnavailableFailure>());
      h.adapter.on('GET', '/v1/coverage/meta', (_) => FakeReply(200, fixture('coverage_meta.json')));
      expect(_ok(await repo.meta()).datasetVersion, 7);
    });
  });

  group('address search', () {
    test('search_prefers_post_address_when_capabilities_allow_else_geocode_get', () async {
      final result = _ok(await repo.search('12 Lifalethu Avenue'));
      expect(result.matched, MatchPrecision.address);
      expect(result.matches.single.label, '12 Lifalethu Avenue, eMbalenhle, Secunda');
      final post = h.adapter.requestsTo('POST', '/v1/coverage/address').single;
      expect(post.data, {'q': '12 Lifalethu Avenue'});
      expect(post.uri.queryParameters, {'tenant': 'sentech'}, reason: 'the address is in the body, never in the URL');
      expect(h.adapter.requestsTo('GET', '/v1/geocode/search'), isEmpty);

      // The address step is off on this deployment: the older search answers.
      h.adapter.on('GET', '/v1/coverage/capabilities', (_) => FakeReply(200, {'shape_version': 2, 'address_lookup': false}));
      final fresh = HttpCoverageRepository(h.api, tenant: h.tenantContext, humanCheck: human, now: () => clock);
      final older = _ok(await fresh.search('Lifalethu'));
      expect(older.matches.single.precision, MatchPrecision.unknown);
      final get = h.adapter.requestsTo('GET', '/v1/geocode/search').single;
      expect(get.uri.queryParameters['q'], 'Lifalethu');
      expect(get.uri.queryParameters['tenant'], 'sentech');
      expect(h.adapter.requestsTo('POST', '/v1/coverage/address'), hasLength(1));
    });

    test('capabilities are read once per session; an older server without them uses the older search', () async {
      await repo.search('abc');
      await repo.search('abcd');
      expect(h.adapter.requestsTo('GET', '/v1/coverage/capabilities'), hasLength(1));
      h.adapter.on('GET', '/v1/coverage/capabilities', (_) => FakeReply.problem(404, 'http_404', title: 'Not Found'));
      final older = HttpCoverageRepository(h.api, tenant: h.tenantContext, humanCheck: human, now: () => clock);
      expect(_ok(await older.search('Lifalethu')).matches, isNotEmpty);
      expect(h.adapter.requestsTo('GET', '/v1/geocode/search'), hasLength(1));
      expect(_ok(await older.addressLookupAvailable()), isFalse);
    });

    test('the address step answering 503 address_lookup_unavailable is its own state, with the Retry-After hint', () async {
      h.adapter.on(
        'POST',
        '/v1/coverage/address',
        (_) => FakeReply.problem(503, 'address_lookup_unavailable', headers: {'retry-after': ['30']}),
      );
      final failure = _failure(await repo.search('Lifalethu'));
      expect(failure, isA<AddressSearchUnavailableFailure>());
      expect((failure! as AddressSearchUnavailableFailure).retryAfter, const Duration(seconds: 30));
      h.adapter.on('POST', '/v1/coverage/address', (_) => FakeReply.problem(422, 'query_too_short'));
      expect(_failure(await repo.search('Lifalethu')), isA<ValidationFailure>());
    });

    test('the older search answering 503 geocoder_unavailable is the same state; 429 carries Retry-After', () async {
      h.adapter.on('GET', '/v1/coverage/capabilities', (_) => FakeReply(200, {'shape_version': 2, 'address_lookup': false}));
      h.adapter.on('GET', '/v1/geocode/search', (_) => FakeReply.problem(503, 'geocoder_unavailable'));
      expect(_failure(await repo.search('Lifalethu')), isA<AddressSearchUnavailableFailure>());
      h.adapter.on('GET', '/v1/geocode/search', (_) => FakeReply.problem(429, 'rate_limited', headers: {'retry-after': ['9']}));
      expect((_failure(await repo.search('Lifalethu'))! as RateLimitedFailure).retryAfter, const Duration(seconds: 9));
    });
  });

  group('leads', () {
    test('submit_lead_sends_the_idempotency_key_and_both_consents_separately', () async {
      _ok(await repo.submitLead(_request(), idempotencyKey: 'app-key-0001'));
      final request = h.adapter.requestsTo('POST', '/v1/leads').single;
      expect(request.headers['Idempotency-Key'], 'app-key-0001');
      expect(request.headers.containsKey('Authorization'), isFalse);
      expect(request.data, {
        'tenant': 'sentech',
        'contact': {'type': 'phone', 'value': '082 123 4567'},
        'address_text': '12 Lifalethu Avenue, eMbalenhle',
        'lat': -26.51423,
        'lon': 29.10311,
        'technology_interest': 'any',
        'consent': {'granted': true, 'version': '2026-10-01'},
        'arrival_consent': {'granted': false, 'version': '2026-11-18'},
        'source': 'app',
        'turnstile_token': 'turnstile-token-1',
      });
      _ok(await repo.submitLead(_request(arrival: true), idempotencyKey: 'app-key-0002'));
      final second = h.adapter.requestsTo('POST', '/v1/leads').last.data as Map;
      expect(second['arrival_consent'], {'granted': true, 'version': '2026-11-18'});
      expect(second['consent'], {'granted': true, 'version': '2026-10-01'});
    });

    test('the technology of interest and an email contact are sent as chosen', () async {
      final request = NotifyRequest(
        contactType: ContactKind.email,
        contactValue: 'Jane@Example.test',
        addressText: '1 Main Street',
        lat: -26.1,
        lon: 28.1,
        technologyInterest: TechnologyInterest.fiveG,
        waitlistConsentVersion: '2026-10-01',
        arrivalConsentGranted: false,
        arrivalConsentVersion: '2026-11-18',
      );
      _ok(await repo.submitLead(request, idempotencyKey: 'app-key-0003'));
      final body = h.adapter.requestsTo('POST', '/v1/leads').single.data as Map;
      expect(body['technology_interest'], '5g');
      expect(body['contact'], {'type': 'email', 'value': 'Jane@Example.test'});
    });

    test('with no widget on the deployment the public dev pass is sent, like the support message', () async {
      human.value = null;
      _ok(await repo.submitLead(_request(), idempotencyKey: 'app-key-0004'));
      expect((h.adapter.requestsTo('POST', '/v1/leads').single.data as Map)['turnstile_token'], devTurnstilePass);
    });

    test('a customer who backs out of the human check sends nothing', () async {
      human.throwing = const HumanCheckCancelled();
      expect(_failure(await repo.submitLead(_request(), idempotencyKey: 'app-key-0005')), isA<HumanCheckCancelledFailure>());
      human.throwing = const HumanCheckUnavailable();
      expect(_failure(await repo.submitLead(_request(), idempotencyKey: 'app-key-0005')), isA<HumanVerificationUnavailableFailure>());
      expect(h.adapter.requestsTo('POST', '/v1/leads'), isEmpty);
    });

    test('each refusal of the lead route has its own typed failure', () async {
      final cases = <(int, String, Type)>[
        (422, 'consent_version_outdated', ConsentVersionOutdatedFailure),
        (422, 'invalid_contact', InvalidContactFailure),
        (422, 'outside_service_area', OutsideServiceAreaFailure),
        (403, 'human_verification_failed', HumanVerificationFailedFailure),
        (503, 'human_verification_unavailable', HumanVerificationUnavailableFailure),
        (429, 'rate_limited', RateLimitedFailure),
        (422, 'consent_required', ValidationFailure),
        (422, 'idempotency_key_reused', ValidationFailure),
        (400, 'idempotency_key_invalid', ValidationFailure),
      ];
      for (final (status, code, type) in cases) {
        h.adapter.on('POST', '/v1/leads', (_) => FakeReply.problem(status, code));
        final failure = _failure(await repo.submitLead(_request(), idempotencyKey: 'app-key-0006'));
        expect(failure.runtimeType, type, reason: code);
      }
    });

    test('an older server without the lead route is the coverage-unavailable state', () async {
      h.adapter.on('POST', '/v1/leads', (_) => FakeReply.problem(404, 'http_404', title: 'Not Found'));
      expect(_failure(await repo.submitLead(_request(), idempotencyKey: 'app-key-0007')), isA<CoverageUnavailableFailure>());
    });

    test('a lost response is a network failure (the screen then keeps the same key)', () async {
      h.adapter.on('POST', '/v1/leads', (_) => FakeReply.error(DioExceptionType.receiveTimeout));
      expect(_failure(await repo.submitLead(_request(), idempotencyKey: 'app-key-0008')), isA<NetworkFailure>());
    });

    test('requestWithdrawal posts the contact and the human check only, to the withdrawal-requests route', () async {
      _ok(
        await repo.requestWithdrawal(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567')),
      );
      final request = h.adapter.requestsTo('POST', '/v1/leads/withdrawal-requests').single;
      expect(request.data, {
        'tenant': 'sentech',
        'contact': {'type': 'phone', 'value': '0821234567'},
        'turnstile_token': 'turnstile-token-1',
      });
      expect(request.headers.containsKey('Idempotency-Key'), isFalse, reason: 'the route does not take one');
      // The app never calls the confirmation route: only the one-time link does.
      expect(h.adapter.requestsTo('POST', '/v1/leads/withdrawals'), isEmpty);
    });

    test('a withdrawal request refused for the contact format, the rate limit or the check maps to typed failures', () async {
      h.adapter.on('POST', '/v1/leads/withdrawal-requests', (_) => FakeReply.problem(422, 'invalid_contact'));
      expect(_failure(await repo.requestWithdrawal(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: 'x'))), isA<InvalidContactFailure>());
      h.adapter.on('POST', '/v1/leads/withdrawal-requests', (_) => FakeReply.problem(429, 'rate_limited', headers: {'retry-after': ['60']}));
      expect(_failure(await repo.requestWithdrawal(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567'))), isA<RateLimitedFailure>());
      h.adapter.on('POST', '/v1/leads/withdrawal-requests', (_) => FakeReply.problem(404, 'http_404', title: 'Not Found'));
      expect(_failure(await repo.requestWithdrawal(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567'))), isA<CoverageUnavailableFailure>());
    });
  });

  group('privacy', () {
    test('no_coordinates_or_contact_values_appear_in_logged_requests', () async {
      await repo.check(lat: -26.51423, lon: 29.10311);
      await repo.search('12 Lifalethu Avenue');
      await repo.submitLead(_request(), idempotencyKey: 'app-key-0009');
      await repo.requestWithdrawal(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567'));
      h.adapter.on('GET', '/v1/coverage/check', (_) => FakeReply.problem(429, 'rate_limited'));
      await repo.check(lat: -26.51423, lon: 29.10311);
      expect(h.logLines, isNotEmpty);
      final logged = h.logLines.join('\n');
      for (final secret in ['26.514', '29.103', 'Lifalethu', '082', '1234567', 'turnstile-token', 'Jane']) {
        expect(logged, isNot(contains(secret)), reason: secret);
      }
    });

    test('a failure never carries the address, the contact or the coordinates in its text', () async {
      h.adapter.on(
        'POST',
        '/v1/leads',
        (_) => FakeReply.problem(422, 'invalid_contact', detail: 'Enter a South African mobile number.'),
      );
      final failure = _failure(await repo.submitLead(_request(), idempotencyKey: 'app-key-0010'))!;
      expect(failure.toString(), isNot(contains('082')));
      expect(failure.toString(), isNot(contains('Lifalethu')));
    });

    test('the request values print redacted', () {
      final text = _request().toString();
      for (final secret in ['082', 'Lifalethu', '26.514', '29.103']) {
        expect(text, isNot(contains(secret)));
      }
      expect(const WithdrawalRequest(contactType: ContactKind.phone, contactValue: '0821234567').toString(), isNot(contains('0821234567')));
    });
  });

  test('the check answer is the typed v2 answer', () async {
    final check = _ok(await repo.check(lat: -26.1, lon: 28.1));
    expect(check.primary!.technology, CoverageTechnology.fiveG);
  });

  test('the waiting list uses the platform lead human check, whose widget action is lead', () {
    expect(HumanCheckAction.lead.widgetAction, 'lead');
    final config = HumanCheckConfig.fromJson(fixture('human_check_config.json'));
    expect(config.requires(HumanCheckAction.lead), config.leadRequired);
  });
}
