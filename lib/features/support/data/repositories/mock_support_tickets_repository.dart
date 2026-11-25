import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/pending_ticket_keys.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_tickets_repository.dart';

/// Named demo states for the ticket screens. The demo flavor uses [normal].
enum TicketsScenario {
  /// Believable tickets, a network incident and a working desk.
  normal,

  /// The feature is off for this provider (every ticket route answers "not available").
  notAvailable,
}

class _MockTicket {
  _MockTicket({
    required this.reference,
    required this.status,
    required this.categoryKey,
    required this.categoryName,
    required this.awaitingReply,
    required this.createdAt,
    required this.updatedAt,
    required this.messages,
  });

  final String reference;
  TicketStatus status;
  final String categoryKey;
  final String categoryName;
  bool awaitingReply;
  final DateTime createdAt;
  DateTime updatedAt;
  final List<TicketMessage> messages;

  Ticket get header => Ticket(
    reference: reference,
    status: status,
    categoryKey: categoryKey,
    categoryName: categoryName,
    awaitingReply: awaitingReply,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Demo and test stand-in for the customer ticket routes, with the server's
/// rules: one idempotency key gives one answer (a repeat never makes a second
/// ticket or message, the same key with other text is refused), a reply reopens
/// a solved ticket, a closed ticket takes no message, and the categories come
/// from the repository. The demo flavor only: the prod flavor never registers it.
///
/// Demo data is made up for the demo and says nothing about response times.
class MockSupportTicketsRepository implements SupportTicketsRepository {
  MockSupportTicketsRepository({
    this.scenario = TicketsScenario.normal,
    DateTime Function()? now,
    this.latency = const Duration(milliseconds: 250),
  }) : _now = now ?? DateTime.now {
    _seed();
  }

  final TicketsScenario scenario;
  final DateTime Function() _now;
  final Duration latency;

  static const _categories = [
    TicketCategory(key: 'billing', name: 'Billing'),
    TicketCategory(key: 'connection', name: 'Connection problems'),
    TicketCategory(key: 'other', name: 'Something else'),
  ];

  final _tickets = <_MockTicket>[];
  final _createKeys = <String, ({int fingerprint, String reference})>{};
  final _replyKeys = <String, ({int fingerprint, String reference})>{};
  int _counter = 0;

  void _seed() {
    final now = _now();
    _tickets
      ..clear()
      ..addAll([
        _MockTicket(
          reference: 'TKT-4N8P2R6T',
          status: TicketStatus.pendingCustomer,
          categoryKey: 'billing',
          categoryName: 'Billing',
          awaitingReply: true,
          createdAt: now.subtract(const Duration(days: 2, hours: 3)),
          updatedAt: now.subtract(const Duration(hours: 20)),
          messages: [
            TicketMessage(
              author: TicketAuthor.you,
              body: 'I was charged twice for my weekly pass on Monday.',
              createdAt: now.subtract(const Duration(days: 2, hours: 3)),
            ),
            TicketMessage(
              author: TicketAuthor.support,
              body: 'Thanks for telling us. Can you tell us the time of the second charge?',
              createdAt: now.subtract(const Duration(hours: 20)),
            ),
          ],
        ),
        _MockTicket(
          reference: 'TKT-9C5H7J1K',
          status: TicketStatus.resolved,
          categoryKey: 'connection',
          categoryName: 'Connection problems',
          awaitingReply: false,
          createdAt: now.subtract(const Duration(days: 9)),
          updatedAt: now.subtract(const Duration(days: 8)),
          messages: [
            TicketMessage(
              author: TicketAuthor.you,
              body: 'The hotspot at the library keeps dropping me.',
              createdAt: now.subtract(const Duration(days: 9)),
            ),
            TicketMessage(
              author: TicketAuthor.support,
              body: 'We restarted that access point. Please reconnect and tell us if it happens again.',
              createdAt: now.subtract(const Duration(days: 8, hours: 2)),
            ),
            TicketMessage(
              author: TicketAuthor.you,
              body: 'It works now, thank you.',
              createdAt: now.subtract(const Duration(days: 8)),
            ),
          ],
        ),
      ]);
    _createKeys.clear();
    _replyKeys.clear();
    _counter = 0;
  }

  /// Puts the demo tickets back (signing out in the demo; the real tickets live on the server).
  void reset() => _seed();

  /// Test and demo helper: support closes the ticket while the customer has it open.
  void closeFromSupport(String reference) {
    final ticket = _find(reference);
    if (ticket == null) return;
    ticket.status = TicketStatus.closed;
    ticket.awaitingReply = false;
    ticket.updatedAt = _now();
  }

  _MockTicket? _find(String reference) {
    for (final t in _tickets) {
      if (t.reference == reference) return t;
    }
    return null;
  }

  Future<Failure?> _gate() async {
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    return scenario == TicketsScenario.notAvailable ? const TicketsNotAvailableFailure() : null;
  }

  @override
  Future<Either<Failure, List<TicketCategory>>> categories() async {
    if (await _gate() case final failure?) return Left(failure);
    return const Right(_categories);
  }

  @override
  Future<Either<Failure, TicketPage>> list({String? cursor}) async {
    if (await _gate() case final failure?) return Left(failure);
    final sorted = [..._tickets]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return Right(TicketPage(items: [for (final t in sorted) t.header]));
  }

  @override
  Future<Either<Failure, TicketThread>> get(String reference) async {
    if (await _gate() case final failure?) return Left(failure);
    final ticket = _find(reference);
    if (ticket == null) return const Left(TicketNotFoundFailure());
    return Right(_thread(ticket));
  }

  TicketThread _thread(_MockTicket t) => TicketThread(
    reference: t.reference,
    status: t.status,
    categoryKey: t.categoryKey,
    categoryName: t.categoryName,
    awaitingReply: t.awaitingReply,
    createdAt: t.createdAt,
    updatedAt: t.updatedAt,
    messages: List.of(t.messages),
  );

  @override
  Future<Either<Failure, String>> create({
    required String categoryKey,
    required String body,
    String? orderId,
    required String idempotencyKey,
  }) async {
    if (await _gate() case final failure?) return Left(failure);
    final fingerprint = PendingTicketKeys.fingerprint(categoryKey, body);
    final earlier = _createKeys[idempotencyKey];
    if (earlier != null) {
      return earlier.fingerprint == fingerprint
          ? Right(earlier.reference)
          : const Left(ValidationFailure('That request key was already used for something else.', 'idempotency_key_reused', false));
    }
    final category = _categories.where((c) => c.key == categoryKey).firstOrNull;
    if (category == null) return const Left(TicketCategoryGoneFailure());
    final now = _now();
    _counter++;
    final reference = 'TKT-DEMO${_counter.toString().padLeft(4, '0')}';
    _tickets.add(
      _MockTicket(
        reference: reference,
        status: TicketStatus.newTicket,
        categoryKey: category.key,
        categoryName: category.name,
        awaitingReply: false,
        createdAt: now,
        updatedAt: now,
        messages: [TicketMessage(author: TicketAuthor.you, body: body, createdAt: now)],
      ),
    );
    _createKeys[idempotencyKey] = (fingerprint: fingerprint, reference: reference);
    return Right(reference);
  }

  @override
  Future<Either<Failure, Ticket>> reply(String reference, {required String body, required String idempotencyKey}) async {
    if (await _gate() case final failure?) return Left(failure);
    final ticket = _find(reference);
    if (ticket == null) return const Left(TicketNotFoundFailure());
    final fingerprint = PendingTicketKeys.fingerprint(reference, body);
    final earlier = _replyKeys[idempotencyKey];
    if (earlier != null) {
      return earlier.fingerprint == fingerprint
          ? Right(ticket.header)
          : const Left(ValidationFailure('That request key was already used for something else.', 'idempotency_key_reused', false));
    }
    if (ticket.status == TicketStatus.closed) return const Left(TicketClosedFailure());
    final now = _now();
    ticket.messages.add(TicketMessage(author: TicketAuthor.you, body: body, createdAt: now));
    // A reply reopens a solved ticket, as on the server.
    ticket.status = TicketStatus.open;
    ticket.awaitingReply = false;
    ticket.updatedAt = now;
    _replyKeys[idempotencyKey] = (fingerprint: fingerprint, reference: reference);
    return Right(ticket.header);
  }

  @override
  Future<Either<Failure, Ticket>> close(String reference) async {
    if (await _gate() case final failure?) return Left(failure);
    final ticket = _find(reference);
    if (ticket == null) return const Left(TicketNotFoundFailure());
    if (ticket.status == TicketStatus.closed) return const Left(TicketClosedFailure());
    if (ticket.status == TicketStatus.resolved) return const Left(TicketAlreadyResolvedFailure());
    ticket.status = TicketStatus.resolved;
    ticket.awaitingReply = false;
    ticket.updatedAt = _now();
    return Right(ticket.header);
  }

  @override
  Future<Either<Failure, List<Incident>>> incidents({String? siteId}) async {
    if (scenario == TicketsScenario.notAvailable) return const Right([]);
    if (latency > Duration.zero) await Future<void>.delayed(latency);
    final now = _now();
    return Right([
      Incident(
        id: 'demo-incident-1',
        title: 'Slow speeds at some hotspots',
        severity: IncidentSeverity.degraded,
        status: IncidentStatus.identified,
        body: 'We have found the cause and are working on it.',
        startedAt: now.subtract(const Duration(hours: 3)),
        resolvedAt: null,
        updates: [
          IncidentUpdate(
            status: IncidentStatus.investigating,
            body: 'We are looking into slow speeds at some hotspots.',
            createdAt: now.subtract(const Duration(hours: 3)),
          ),
          IncidentUpdate(
            status: IncidentStatus.identified,
            body: 'We have found the cause and are working on it.',
            createdAt: now.subtract(const Duration(hours: 1)),
          ),
        ],
      ),
    ]);
  }
}
