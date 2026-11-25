import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/repositories/mock_support_tickets_repository.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';

T _ok<T>(Either<Failure, T> either) => either.getOrElse((f) => throw StateError('${f.runtimeType}'));

Failure? _failure<T>(Either<Failure, T> either) => either.match((f) => f, (_) => null);

void main() {
  late MockSupportTicketsRepository repo;

  setUp(() => repo = MockSupportTicketsRepository(latency: Duration.zero, now: () => DateTime.utc(2026, 11, 26, 9)));

  test('the demo starts with believable tickets, one waiting for the customer, with references', () async {
    final page = _ok(await repo.list());
    expect(page.items.length, greaterThanOrEqualTo(2));
    expect(page.items.any((t) => t.awaitingReply), isTrue);
    for (final ticket in page.items) {
      expect(ticket.reference, matches(RegExp(r'^[A-Z]{3}-[A-Z0-9]{8}$')));
    }
    final thread = _ok(await repo.get(page.items.first.reference));
    expect(thread.messages, isNotEmpty);
  });

  test('categories come from the repository, not the screen', () async {
    expect(_ok(await repo.categories()), isNotEmpty);
  });

  test('one key gives one ticket: a repeat with the same text returns the same reference, another text is refused', () async {
    final first = _ok(await repo.create(categoryKey: 'billing', body: 'Charged twice', idempotencyKey: 'key-00000001'));
    final again = _ok(await repo.create(categoryKey: 'billing', body: 'Charged twice', idempotencyKey: 'key-00000001'));
    expect(again, first);
    final before = _ok(await repo.list()).items.length;
    final reused = _failure(await repo.create(categoryKey: 'billing', body: 'Something else', idempotencyKey: 'key-00000001'));
    expect((reused! as ValidationFailure).code, 'idempotency_key_reused');
    expect(_ok(await repo.list()).items.length, before);
    expect(_ok(await repo.list()).items.first.reference, first, reason: 'newest first');
  });

  test('an unknown category is refused like the server does', () async {
    expect(_failure(await repo.create(categoryKey: 'nope', body: 'x', idempotencyKey: 'key-00000002')), isA<TicketCategoryGoneFailure>());
  });

  test('a reply is added once per key, reopens a solved ticket and a closed ticket refuses it', () async {
    final reference = _ok(await repo.create(categoryKey: 'billing', body: 'Hello', idempotencyKey: 'key-00000003'));
    _ok(await repo.reply(reference, body: 'More', idempotencyKey: 'key-00000004'));
    _ok(await repo.reply(reference, body: 'More', idempotencyKey: 'key-00000004'));
    var thread = _ok(await repo.get(reference));
    expect(thread.messages.where((m) => m.body == 'More'), hasLength(1));
    final solved = _ok(await repo.close(reference));
    expect(solved.status, TicketStatus.resolved);
    expect(_failure(await repo.close(reference)), isA<TicketAlreadyResolvedFailure>());
    final reopened = _ok(await repo.reply(reference, body: 'Still broken', idempotencyKey: 'key-00000005'));
    expect(reopened.status, TicketStatus.open);
    thread = _ok(await repo.get(reference));
    expect(thread.status, TicketStatus.open);
    repo.closeFromSupport(reference);
    expect(_failure(await repo.reply(reference, body: 'late', idempotencyKey: 'key-00000006')), isA<TicketClosedFailure>());
    expect(_failure(await repo.close(reference)), isA<TicketClosedFailure>());
  });

  test('an unknown reference is a ticket-not-found failure, never a crash', () async {
    expect(_failure(await repo.get('TKT-ZZZZZZZZ')), isA<TicketNotFoundFailure>());
    expect(_failure(await repo.reply('TKT-ZZZZZZZZ', body: 'x', idempotencyKey: 'key-00000007')), isA<TicketNotFoundFailure>());
  });

  test('reset puts the demo tickets back (sign-out in the demo)', () async {
    final reference = _ok(await repo.create(categoryKey: 'billing', body: 'Hello', idempotencyKey: 'key-00000008'));
    repo.reset();
    expect(_failure(await repo.get(reference)), isA<TicketNotFoundFailure>());
    expect(_ok(await repo.list()).items.length, greaterThanOrEqualTo(2));
  });

  test('the demo incident is a plain notice with the provider\'s words', () async {
    final incidents = _ok(await repo.incidents());
    expect(incidents, isNotEmpty);
    expect(incidents.first.isOpen, isTrue);
  });

  test('the scenario that turns the feature off answers not available everywhere', () async {
    final off = MockSupportTicketsRepository(latency: Duration.zero, scenario: TicketsScenario.notAvailable);
    expect(_failure(await off.list()), isA<TicketsNotAvailableFailure>());
    expect(_failure(await off.categories()), isA<TicketsNotAvailableFailure>());
    expect(_failure(await off.get('TKT-7K3M9Q2A')), isA<TicketsNotAvailableFailure>());
  });
}
