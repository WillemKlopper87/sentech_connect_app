import 'package:fpdart/fpdart.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';

/// The customer's support tickets and the public incident notices. Where the
/// provider has ticketing off, or the server is older than the routes, the
/// ticket calls fail with [TicketsNotAvailableFailure] and the screens hide the
/// feature; the one-way contact form (`SupportMessageRepository`) stays.
///
/// Ticket text is personal data: implementations never log or keep it.
abstract class SupportTicketsRepository {
  /// What a ticket can be about, as the provider set it up.
  Future<Either<Failure, List<TicketCategory>>> categories();

  /// Newest first; pass the previous page's `nextCursor` for the next page.
  Future<Either<Failure, TicketPage>> list({String? cursor});

  Future<Either<Failure, TicketThread>> get(String reference);

  /// Opens a ticket and returns its reference. Reusing [idempotencyKey] with
  /// the same body after a lost response returns the same reference and never
  /// opens a second ticket. [orderId] is optional and one of the customer's own
  /// orders; the v1 screens do not offer it.
  Future<Either<Failure, String>> create({
    required String categoryKey,
    required String body,
    String? orderId,
    required String idempotencyKey,
  });

  /// Adds a message and returns the ticket's new header (a solved ticket reopens).
  Future<Either<Failure, Ticket>> reply(String reference, {required String body, required String idempotencyKey});

  /// The customer marks the ticket solved ([TicketStatus.resolved]).
  Future<Either<Failure, Ticket>> close(String reference);

  /// Open incidents and those resolved in the last 24 hours (public route).
  Future<Either<Failure, List<Incident>>> incidents({String? siteId});
}
