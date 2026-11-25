import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/diagnostics/pii_scrubber.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/http_support_tickets_repository.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';

import '../helpers/api_harness.dart';
import '../helpers/fake_http_adapter.dart';
import '../helpers/fixtures.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError('${f.runtimeType}: ${f.message}'));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

Map<String, Object?> _firstTicket() => Map<String, Object?>.from((fixtureMap('tickets_page.json')['items']! as List).first as Map);

const _ref = 'TKT-7K3M9Q2A';
const _key = 'app-key-0000001';

void main() {
  late ApiHarness h;
  late HttpSupportTicketsRepository repo;
  late List<String> refused;

  setUp(() async {
    h = ApiHarness();
    await h.signIn();
    refused = [];
    repo = HttpSupportTicketsRepository(h.api, tenant: h.tenantContext, onModuleRefused: refused.add);
  });

  test('create_sends_the_idempotency_key_and_body', () async {
    h.adapter.on('POST', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply(201, fixture('ticket_created.json')));
    final reference = _ok(await repo.create(categoryKey: 'billing', body: 'I was charged twice.', idempotencyKey: _key));
    expect(reference, _ref);
    final request = h.adapter.requests.single;
    expect(request.headers['Idempotency-Key'], _key);
    expect(request.headers['Authorization'], 'Bearer access-1');
    expect(request.data, {'category': 'billing', 'body': 'I was charged twice.'});
  });

  test('create_sends_an_order_link_only_when_given', () async {
    h.adapter.on('POST', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply(201, fixture('ticket_created.json')));
    await repo.create(categoryKey: 'billing', body: 'x', orderId: '0b9c3a52-6f1e-4c0e-9d5a-1a2b3c4d5e6f', idempotencyKey: _key);
    expect((h.adapter.requests.single.data as Map)['order_id'], '0b9c3a52-6f1e-4c0e-9d5a-1a2b3c4d5e6f');
  });

  test('reply_sends_the_idempotency_key_and_returns_the_new_header', () async {
    h.adapter.on('POST', '/v1/me/tickets/$_ref/messages', (_) => FakeReply(201, _firstTicket()));
    final ticket = _ok(await repo.reply(_ref, body: 'The 3rd of November.', idempotencyKey: _key));
    expect(ticket.reference, _ref);
    expect(ticket.status, TicketStatus.pendingCustomer);
    final request = h.adapter.requests.single;
    expect(request.headers['Idempotency-Key'], _key);
    expect(request.data, {'body': 'The 3rd of November.'});
  });

  test('close_marks_the_ticket_solved_and_sends_no_body', () async {
    final solved = {..._firstTicket(), 'status': 'resolved', 'awaiting_reply': false};
    h.adapter.on('POST', '/v1/me/tickets/$_ref/close', (_) => FakeReply(200, solved));
    final ticket = _ok(await repo.close(_ref));
    expect(ticket.status, TicketStatus.resolved);
    expect(h.adapter.requests.single.data, isNull);
  });

  test('get_decodes_the_thread', () async {
    h.adapter.on('GET', '/v1/me/tickets/$_ref', (_) => FakeReply(200, fixture('ticket_detail.json')));
    final thread = _ok(await repo.get(_ref));
    expect(thread.messages, hasLength(2));
  });

  test('categories_come_from_the_server', () async {
    h.adapter.on('GET', HttpSupportTicketsRepository.categoriesPath, (_) => FakeReply(200, fixture('ticket_categories.json')));
    expect(_ok(await repo.categories()).map((c) => c.key), ['billing', 'connection', 'other']);
  });

  test('reply_to_a_closed_ticket_maps_to_a_closed_failure', () async {
    h.adapter.on('POST', '/v1/me/tickets/$_ref/messages', (_) => FakeReply.problem(409, 'ticket_closed'));
    expect(_failure(await repo.reply(_ref, body: 'hello', idempotencyKey: _key)), isA<TicketClosedFailure>());
    h.adapter.on('POST', '/v1/me/tickets/$_ref/close', (_) => FakeReply.problem(409, 'ticket_closed'));
    expect(_failure(await repo.close(_ref)), isA<TicketClosedFailure>());
  });

  test('the_other_refusals_have_their_own_typed_failures', () async {
    h.adapter.on('POST', '/v1/me/tickets/$_ref/close', (_) => FakeReply.problem(409, 'ticket_already_resolved'));
    expect(_failure(await repo.close(_ref)), isA<TicketAlreadyResolvedFailure>());
    h.adapter.on('POST', '/v1/me/tickets/$_ref/close', (_) => FakeReply.problem(409, 'ticket_version_conflict'));
    expect(_failure(await repo.close(_ref)), isA<TicketChangedFailure>());
    h.adapter.on('GET', '/v1/me/tickets/$_ref', (_) => FakeReply.problem(404, 'ticket_not_found'));
    expect(_failure(await repo.get(_ref)), isA<TicketNotFoundFailure>());
    h.adapter.on('POST', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply.problem(422, 'category_not_found'));
    expect(_failure(await repo.create(categoryKey: 'gone', body: 'x', idempotencyKey: _key)), isA<TicketCategoryGoneFailure>());
    h.adapter.on('POST', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply.problem(422, 'idempotency_key_reused'));
    final reused = _failure(await repo.create(categoryKey: 'a', body: 'x', idempotencyKey: _key));
    expect(reused, isA<ValidationFailure>());
    expect((reused! as ValidationFailure).code, 'idempotency_key_reused');
    h.adapter.on('POST', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply.problem(409, 'idempotency_in_progress'));
    expect(_failure(await repo.create(categoryKey: 'a', body: 'x', idempotencyKey: _key)), isA<IdempotencyInProgressFailure>());
  });

  test('a_429_carries_retry_after', () async {
    h.adapter.on(
      'POST',
      HttpSupportTicketsRepository.ticketsPath,
      (_) => FakeReply.problem(429, 'rate_limited', headers: {'retry-after': ['1800']}),
    );
    final failure = _failure(await repo.create(categoryKey: 'a', body: 'x', idempotencyKey: _key));
    expect(failure, isA<RateLimitedFailure>());
    expect((failure! as RateLimitedFailure).retryAfter, const Duration(minutes: 30));
  });

  test('an_older_server_without_the_route_maps_to_unavailable', () async {
    // The fake adapter answers an unknown route with a plain 404 problem, as an older server does.
    expect(_failure(await repo.list()), isA<TicketsNotAvailableFailure>());
    expect(_failure(await repo.categories()), isA<TicketsNotAvailableFailure>());
    expect(_failure(await repo.get(_ref)), isA<TicketsNotAvailableFailure>());
    expect(_failure(await repo.create(categoryKey: 'a', body: 'x', idempotencyKey: _key)), isA<TicketsNotAvailableFailure>());
    expect(_failure(await repo.reply(_ref, body: 'x', idempotencyKey: _key)), isA<TicketsNotAvailableFailure>());
    // A missing route on list, categories and create hides the entry at once (the Help tab flips back to the old form);
    // a plain 404 on one thread is not a missing feature.
    expect(refused, ['tickets', 'tickets', 'tickets']);
  });

  test('feature_off_and_module_off_are_unavailable_and_409_hides_the_entry', () async {
    h.adapter.on('GET', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply.problem(409, 'feature_disabled'));
    expect(_failure(await repo.list()), isA<TicketsNotAvailableFailure>());
    expect(refused, ['tickets']);
    h.adapter.on('GET', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply.problem(403, 'module_not_enabled'));
    expect(_failure(await repo.list()), isA<TicketsNotAvailableFailure>());
  });

  test('list_follows_the_cursor', () async {
    h.adapter.on('GET', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply(200, fixture('tickets_page.json')));
    final page = _ok(await repo.list());
    expect(page.nextCursor, 'c2VudGVjaA');
    expect(h.adapter.requests.last.queryParameters, isEmpty);
    await repo.list(cursor: page.nextCursor);
    expect(h.adapter.requests.last.queryParameters, {'cursor': 'c2VudGVjaA'});
  });

  test('a_reference_that_is_not_a_reference_never_reaches_a_path', () async {
    final failure = _failure(await repo.get('../../v1/me'));
    expect(failure, isA<TicketNotFoundFailure>());
    expect(_failure(await repo.close('tkt-lower')), isA<TicketNotFoundFailure>());
    expect(h.adapter.requests, isEmpty);
  });

  test('no_ticket_text_or_reference_appears_in_logged_requests', () async {
    h.adapter.on('POST', HttpSupportTicketsRepository.ticketsPath, (_) => FakeReply(201, fixture('ticket_created.json')));
    h.adapter.on('POST', '/v1/me/tickets/$_ref/messages', (_) => FakeReply.problem(409, 'ticket_closed'));
    h.adapter.on('GET', '/v1/me/tickets/$_ref', (_) => FakeReply(200, fixture('ticket_detail.json')));
    await repo.create(categoryKey: 'billing', body: 'My secret complaint about Mr Smith', idempotencyKey: _key);
    await repo.reply(_ref, body: 'My secret complaint about Mr Smith', idempotencyKey: _key);
    await repo.get(_ref);
    final logged = h.logLines.join('\n');
    expect(logged, isNotEmpty);
    expect(logged, isNot(contains('secret complaint')));
    expect(logged, isNot(contains('Smith')));
    expect(logged, isNot(contains(_ref)));
    expect(logged, isNot(contains('7K3M9Q2A')));
    expect(PiiScrubber.scrub('[api] GET /v1/me/tickets/ESC-ABCD1234 -> 200'), isNot(contains('ABCD1234')));
  });

  test('incidents_sends_the_tenant_and_optional_site', () async {
    h.adapter.on('GET', HttpSupportTicketsRepository.incidentsPath, (_) => FakeReply(200, fixture('incidents_public.json')));
    final incidents = _ok(await repo.incidents());
    expect(incidents.single.severity, IncidentSeverity.degraded);
    var request = h.adapter.requests.single;
    expect(request.queryParameters, {'tenant': 'sentech'});
    expect(request.headers.containsKey('Authorization'), isFalse, reason: 'the incidents route is public');
    await repo.incidents(siteId: '0b9c3a52-6f1e-4c0e-9d5a-1a2b3c4d5e6f');
    request = h.adapter.requests.last;
    expect(request.queryParameters, {'tenant': 'sentech', 'site_id': '0b9c3a52-6f1e-4c0e-9d5a-1a2b3c4d5e6f'});
  });

  test('a_network_failure_is_a_network_failure_and_a_garbled_answer_is_not_a_crash', () async {
    h.adapter.on('GET', HttpSupportTicketsRepository.ticketsPath, (_) => const FakeReply.error(DioExceptionType.connectionError));
    expect(_failure(await repo.list()), isA<NetworkFailure>());
    h.adapter.on('GET', '/v1/me/tickets/$_ref', (_) => const FakeReply(200, ['not', 'an', 'object']));
    expect(_failure(await repo.get(_ref)), isNotNull);
    h.adapter.on('GET', HttpSupportTicketsRepository.ticketsPath, (_) => const FakeReply(200, {'items': 5}));
    expect(_ok(await repo.list()).items, isEmpty);
  });
}
