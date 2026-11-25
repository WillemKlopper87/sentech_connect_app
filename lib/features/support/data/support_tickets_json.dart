import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';

/// Decoders for the customer ticket answers (`/v1/me/tickets*`) and the public
/// incidents answer. Lenient on purpose: an unfamiliar status, author or
/// severity decodes to `unknown`, a row that cannot be read is skipped and the
/// rest still shows, and nothing here throws for a list. Only a ticket THREAD
/// without a reference or a date throws (the caller maps that to a plain
/// "unexpected response" failure). Fields the app does not model, such as
/// anything a newer server adds, are ignored and never kept.

Map<String, Object?>? _asMap(Object? value) => value is Map ? Map<String, Object?>.from(value) : null;

DateTime? _time(Object? value) => value is String ? DateTime.tryParse(value)?.toUtc() : null;

TicketStatus ticketStatusFromApi(Object? value) => switch (value) {
  'new' => TicketStatus.newTicket,
  'open' => TicketStatus.open,
  'pending_customer' => TicketStatus.pendingCustomer,
  'on_hold' => TicketStatus.onHold,
  'resolved' => TicketStatus.resolved,
  'closed' => TicketStatus.closed,
  _ => TicketStatus.unknown,
};

TicketAuthor ticketAuthorFromApi(Object? value) => switch (value) {
  'you' => TicketAuthor.you,
  'support' => TicketAuthor.support,
  _ => TicketAuthor.unknown,
};

IncidentSeverity incidentSeverityFromApi(Object? value) => switch (value) {
  'info' => IncidentSeverity.info,
  'degraded' => IncidentSeverity.degraded,
  'outage' => IncidentSeverity.outage,
  _ => IncidentSeverity.unknown,
};

IncidentStatus incidentStatusFromApi(Object? value) => switch (value) {
  'investigating' => IncidentStatus.investigating,
  'identified' => IncidentStatus.identified,
  'monitoring' => IncidentStatus.monitoring,
  'resolved' => IncidentStatus.resolved,
  _ => IncidentStatus.unknown,
};

/// A ticket header, or null when the row has no reference or no creation time.
Ticket? _ticketOrNull(Map<String, Object?> json) {
  final reference = json['reference'];
  final createdAt = _time(json['created_at']);
  if (reference is! String || reference.isEmpty || createdAt == null) return null;
  final category = json['category'];
  final categoryName = json['category_name'];
  return Ticket(
    reference: reference,
    status: ticketStatusFromApi(json['status']),
    categoryKey: category is String ? category : '',
    categoryName: categoryName is String ? categoryName : '',
    awaitingReply: json['awaiting_reply'] == true,
    createdAt: createdAt,
    updatedAt: _time(json['updated_at']) ?? createdAt,
  );
}

/// `MyTicketItem` -> [Ticket]. Throws [FormatException] without a reference.
Ticket ticketFromJson(Map<String, Object?> json) =>
    _ticketOrNull(json) ?? (throw const FormatException('Malformed ticket'));

/// `MyTicketDetail` -> [TicketThread]. A message that cannot be read is
/// skipped; a null body (text removed by retention) is kept as null.
TicketThread ticketThreadFromJson(Map<String, Object?> json) {
  final ticket = ticketFromJson(json);
  final messages = <TicketMessage>[];
  final raw = json['messages'];
  if (raw is List) {
    for (final item in raw) {
      final map = _asMap(item);
      final createdAt = _time(map?['created_at']);
      if (map == null || createdAt == null) continue;
      final body = map['body'];
      messages.add(
        TicketMessage(author: ticketAuthorFromApi(map['author']), body: body is String ? body : null, createdAt: createdAt),
      );
    }
  }
  return TicketThread(
    reference: ticket.reference,
    status: ticket.status,
    categoryKey: ticket.categoryKey,
    categoryName: ticket.categoryName,
    awaitingReply: ticket.awaitingReply,
    createdAt: ticket.createdAt,
    updatedAt: ticket.updatedAt,
    messages: messages,
  );
}

/// `Page[MyTicketItem]` -> [TicketPage].
TicketPage ticketPageFromJson(Map<String, Object?> json) {
  final items = <Ticket>[];
  final raw = json['items'];
  if (raw is List) {
    for (final item in raw) {
      final map = _asMap(item);
      final ticket = map == null ? null : _ticketOrNull(map);
      if (ticket != null) items.add(ticket);
    }
  }
  final cursor = json['next_cursor'];
  return TicketPage(items: items, nextCursor: cursor is String && cursor.isNotEmpty ? cursor : null);
}

/// `MyCategoryList` -> categories. A category needs a key and a name.
List<TicketCategory> ticketCategoriesFromJson(Map<String, Object?> json) {
  final raw = json['items'];
  if (raw is! List) return const [];
  final categories = <TicketCategory>[];
  for (final item in raw) {
    final map = _asMap(item);
    final slug = map?['slug'];
    final name = map?['name'];
    if (slug is String && slug.isNotEmpty && name is String && name.isNotEmpty) {
      categories.add(TicketCategory(key: slug, name: name));
    }
  }
  return categories;
}

/// `PublicIncidentList` -> incidents (newest first, as the server sends them).
List<Incident> incidentsFromJson(Map<String, Object?> json) {
  final raw = json['items'];
  if (raw is! List) return const [];
  final incidents = <Incident>[];
  for (final item in raw) {
    final map = _asMap(item);
    if (map == null) continue;
    final id = map['id'];
    final title = map['title'];
    final startedAt = _time(map['started_at']);
    if (id is! String || title is! String || title.isEmpty || startedAt == null) continue;
    final updates = <IncidentUpdate>[];
    if (map['updates'] case final List list) {
      for (final u in list) {
        final um = _asMap(u);
        final at = _time(um?['created_at']);
        final body = um?['body'];
        if (um == null || at == null || body is! String) continue;
        updates.add(IncidentUpdate(status: incidentStatusFromApi(um['status']), body: body, createdAt: at));
      }
    }
    final body = map['body'];
    incidents.add(
      Incident(
        id: id,
        title: title,
        severity: incidentSeverityFromApi(map['severity']),
        status: incidentStatusFromApi(map['status']),
        body: body is String ? body : '',
        startedAt: startedAt,
        resolvedAt: _time(map['resolved_at']),
        updates: updates,
      ),
    );
  }
  return incidents;
}
