import 'dart:async';

import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/data/support_tickets_json.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/domain/repositories/support_tickets_repository.dart';

import '../helpers/fixtures.dart';

Ticket ticketFixture({String reference = 'TKT-7K3M9Q2A', TicketStatus status = TicketStatus.pendingCustomer, bool awaiting = true}) =>
    Ticket(
      reference: reference,
      status: status,
      categoryKey: 'billing',
      categoryName: 'Billing',
      awaitingReply: awaiting,
      createdAt: DateTime.utc(2026, 11, 20, 8, 15),
      updatedAt: DateTime.utc(2026, 11, 21, 9, 30),
    );

TicketThread threadFixture([String name = 'ticket_detail.json']) => ticketThreadFromJson(fixtureMap(name));

List<TicketCategory> categoriesFixture() => ticketCategoriesFromJson(fixtureMap('ticket_categories.json'));

List<Incident> incidentsFixture() => incidentsFromJson(fixtureMap('incidents_public.json'));

/// A scriptable [SupportTicketsRepository]: every call is recorded, and an
/// answer is either immediate or held on a [Completer] so a test can act while
/// a request is in flight.
class FakeSupportTicketsRepository implements SupportTicketsRepository {
  Either<Failure, List<TicketCategory>> categoriesResult = Right(categoriesFixture());
  final listPages = <String?, Either<Failure, TicketPage>>{};
  Either<Failure, TicketThread> threadResult = Right(threadFixture());
  Either<Failure, List<Incident>> incidentsResult = Right(incidentsFixture());

  /// Answers to successive create, reply and close calls; the last one repeats.
  final createResults = <Either<Failure, String>>[];
  final replyResults = <Either<Failure, Ticket>>[];
  final closeResults = <Either<Failure, Ticket>>[];

  /// When set, the next create or reply waits for it.
  Completer<void>? sendGate;

  /// When set, the next thread read waits for it (and then answers the thread it had when it STARTED).
  Completer<void>? getGate;

  final createCalls = <({String category, String body, String key})>[];
  final replyCalls = <({String reference, String body, String key})>[];
  final closeCalls = <String>[];
  final listCursors = <String?>[];
  int categoriesCalls = 0;
  int getCalls = 0;
  int incidentsCalls = 0;

  @override
  Future<Either<Failure, List<TicketCategory>>> categories() async {
    categoriesCalls++;
    return categoriesResult;
  }

  @override
  Future<Either<Failure, TicketPage>> list({String? cursor}) async {
    listCursors.add(cursor);
    return listPages[cursor] ?? const Right(TicketPage(items: []));
  }

  @override
  Future<Either<Failure, TicketThread>> get(String reference) async {
    getCalls++;
    final answer = threadResult;
    await getGate?.future;
    return answer;
  }

  @override
  Future<Either<Failure, String>> create({
    required String categoryKey,
    required String body,
    String? orderId,
    required String idempotencyKey,
  }) async {
    createCalls.add((category: categoryKey, body: body, key: idempotencyKey));
    await sendGate?.future;
    final index = createCalls.length - 1;
    return createResults.isEmpty
        ? const Right('TKT-7K3M9Q2A')
        : createResults[index < createResults.length ? index : createResults.length - 1];
  }

  @override
  Future<Either<Failure, Ticket>> reply(String reference, {required String body, required String idempotencyKey}) async {
    replyCalls.add((reference: reference, body: body, key: idempotencyKey));
    await sendGate?.future;
    final index = replyCalls.length - 1;
    return replyResults.isEmpty
        ? Right(ticketFixture(awaiting: false, status: TicketStatus.open))
        : replyResults[index < replyResults.length ? index : replyResults.length - 1];
  }

  @override
  Future<Either<Failure, Ticket>> close(String reference) async {
    closeCalls.add(reference);
    final index = closeCalls.length - 1;
    return closeResults.isEmpty
        ? Right(ticketFixture(status: TicketStatus.resolved, awaiting: false))
        : closeResults[index < closeResults.length ? index : closeResults.length - 1];
  }

  @override
  Future<Either<Failure, List<Incident>>> incidents({String? siteId}) async {
    incidentsCalls++;
    return incidentsResult;
  }
}
