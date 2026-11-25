import 'package:equatable/equatable.dart';

/// The server's ticket status (`new`, `open`, `pending_customer`, `on_hold`,
/// `resolved`, `closed`). A value the app does not know is [unknown] and is
/// shown neutrally, never as "resolved".
enum TicketStatus { newTicket, open, pendingCustomer, onHold, resolved, closed, unknown }

/// Who wrote a message, as the customer routes say it: `you` or `support`.
/// Nothing more is sent (no staff name or id), so nothing more is shown.
enum TicketAuthor { you, support, unknown }

/// One of the customer's tickets. Identified by its [reference] (for example
/// `TKT-7K3M9Q2A`): the customer routes never expose an internal id.
class Ticket extends Equatable {
  const Ticket({
    required this.reference,
    required this.status,
    required this.categoryKey,
    required this.categoryName,
    required this.awaitingReply,
    required this.createdAt,
    required this.updatedAt,
  });

  final String reference;
  final TicketStatus status;
  final String categoryKey;

  /// The provider's own category name; empty when the server sent none.
  final String categoryName;

  /// Support answered last and is waiting for the customer.
  final bool awaitingReply;
  final DateTime createdAt;
  final DateTime updatedAt;

  /// A closed ticket takes no more messages (409 `ticket_closed`).
  bool get isClosed => status == TicketStatus.closed;

  /// Solved by support or by the customer. A reply reopens it; closed is final.
  bool get isResolved => status == TicketStatus.resolved;

  @override
  List<Object?> get props => [reference, status, categoryKey, categoryName, awaitingReply, createdAt, updatedAt];
}

/// One message the customer may read. [body] is null once the server has
/// removed the text (retention); it is never an empty string.
class TicketMessage extends Equatable {
  const TicketMessage({required this.author, required this.body, required this.createdAt});

  final TicketAuthor author;
  final String? body;
  final DateTime createdAt;

  @override
  List<Object?> get props => [author, body, createdAt];
}

/// A ticket with its public messages, oldest first, in the server's order.
class TicketThread extends Ticket {
  const TicketThread({
    required super.reference,
    required super.status,
    required super.categoryKey,
    required super.categoryName,
    required super.awaitingReply,
    required super.createdAt,
    required super.updatedAt,
    required this.messages,
  });

  final List<TicketMessage> messages;

  /// The thread's header as a plain [Ticket] (what a list row shows).
  Ticket get summary => Ticket(
    reference: reference,
    status: status,
    categoryKey: categoryKey,
    categoryName: categoryName,
    awaitingReply: awaitingReply,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  /// This thread with the header of [ticket] (same reference) and the same messages.
  TicketThread withHeader(Ticket ticket) => TicketThread(
    reference: ticket.reference,
    status: ticket.status,
    categoryKey: ticket.categoryKey,
    categoryName: ticket.categoryName,
    awaitingReply: ticket.awaitingReply,
    createdAt: ticket.createdAt,
    updatedAt: ticket.updatedAt,
    messages: messages,
  );

  /// This thread with other messages (for example after a reply was added).
  TicketThread withMessages(List<TicketMessage> next) => TicketThread(
    reference: reference,
    status: status,
    categoryKey: categoryKey,
    categoryName: categoryName,
    awaitingReply: awaitingReply,
    createdAt: createdAt,
    updatedAt: updatedAt,
    messages: next,
  );

  @override
  List<Object?> get props => [...super.props, messages];
}

/// A category the customer may pick when opening a ticket, as the server lists it.
class TicketCategory extends Equatable {
  const TicketCategory({required this.key, required this.name});

  final String key;
  final String name;

  @override
  List<Object?> get props => [key, name];
}

/// One keyset page of the customer's tickets, newest first.
class TicketPage extends Equatable {
  const TicketPage({required this.items, this.nextCursor});

  final List<Ticket> items;
  final String? nextCursor;

  @override
  List<Object?> get props => [items, nextCursor];
}

/// The server's body limit for a ticket or a message (`MyTicketCreateIn.body`,
/// `MyMessageIn.body`: 1 to 4000 characters).
const ticketBodyMaxLength = 4000;
