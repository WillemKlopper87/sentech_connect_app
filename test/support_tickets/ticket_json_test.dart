import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/support/data/support_tickets_json.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';

import '../helpers/fixtures.dart';

void main() {
  test('parses_the_contract_examples', () {
    final page = ticketPageFromJson(fixtureMap('tickets_page.json'));
    expect(page.items.map((t) => t.reference), ['TKT-7K3M9Q2A', 'TKT-2B8D4F6H']);
    expect(page.nextCursor, 'c2VudGVjaA');
    final first = page.items.first;
    expect(first.status, TicketStatus.pendingCustomer);
    expect(first.awaitingReply, isTrue);
    expect(first.categoryKey, 'billing');
    expect(first.categoryName, 'Billing');
    expect(first.createdAt, DateTime.utc(2026, 11, 20, 8, 15));
    expect(page.items.last.awaitingReply, isFalse);

    final thread = ticketThreadFromJson(fixtureMap('ticket_detail.json'));
    expect(thread.reference, 'TKT-7K3M9Q2A');
    expect(thread.messages, hasLength(2));
    expect(thread.messages.first.author, TicketAuthor.you);
    expect(thread.messages.last.author, TicketAuthor.support);

    final categories = ticketCategoriesFromJson(fixtureMap('ticket_categories.json'));
    expect(categories.map((c) => c.key), ['billing', 'connection', 'other']);
    expect(categories.first.name, 'Billing');

    final incidents = incidentsFromJson(fixtureMap('incidents_public.json'));
    expect(incidents.single.severity, IncidentSeverity.degraded);
    expect(incidents.single.status, IncidentStatus.identified);
    expect(incidents.single.resolvedAt, isNull);
    expect(incidents.single.updates, hasLength(2));
    expect(incidents.single.isOpen, isTrue);
  });

  test('unknown_status_author_severity_do_not_throw', () {
    final item = <String, Object?>{
      'reference': 'TKT-AAAAAAAA',
      'status': 'waiting_on_aliens',
      'category': 'new_thing',
      'category_name': 'A new thing',
      'created_at': '2026-11-20T08:15:00Z',
      'updated_at': '2026-11-20T08:15:00Z',
      'awaiting_reply': false,
    };
    expect(ticketFromJson(item).status, TicketStatus.unknown);
    final thread = ticketThreadFromJson({
      ...item,
      'messages': [
        {'author': 'robot', 'body': 'hi', 'created_at': '2026-11-20T08:15:00Z'},
      ],
    });
    expect(thread.messages.single.author, TicketAuthor.unknown);
    final incidents = incidentsFromJson({
      'items': [
        {
          'id': 'x',
          'title': 'T',
          'severity': 'catastrophe',
          'status': 'wobbling',
          'body': 'b',
          'started_at': '2026-11-25T06:00:00Z',
        },
      ],
    });
    expect(incidents.single.severity, IncidentSeverity.unknown);
    expect(incidents.single.status, IncidentStatus.unknown);
    // An unfamiliar status of an incident that is not resolved still counts as open: never claim it ended.
    expect(incidents.single.isOpen, isTrue);
  });

  test('nulls_and_missing_optional_fields_are_handled', () {
    final thread = ticketThreadFromJson({
      'reference': 'TKT-AAAAAAAA',
      'status': 'closed',
      'category': 'billing',
      'category_name': null,
      'created_at': '2026-11-20T08:15:00Z',
      'messages': [
        {'author': 'support', 'body': null, 'created_at': '2026-11-20T08:15:00Z'},
        {'author': 'you', 'created_at': 'not a date'},
        'garbage',
      ],
    });
    expect(thread.categoryName, '');
    expect(thread.awaitingReply, isFalse);
    expect(thread.updatedAt, thread.createdAt);
    // A removed text (retention) is null, never an empty string shown as a message.
    expect(thread.messages, hasLength(1));
    expect(thread.messages.single.body, isNull);
    // A list answer with a broken row keeps the good rows and an absent cursor is the end.
    final page = ticketPageFromJson({
      'items': [
        {'status': 'open'},
        fixtureMap('ticket_detail.json'),
        null,
      ],
    });
    expect(page.items.map((t) => t.reference), ['TKT-7K3M9Q2A']);
    expect(page.nextCursor, isNull);
    expect(ticketCategoriesFromJson({'items': [{'slug': 'a'}, {'slug': 'b', 'name': 'B'}, 7]}).map((c) => c.key), ['b']);
    expect(incidentsFromJson({'items': 'oops'}), isEmpty);
  });

  test('messages_keep_order_and_never_expose_staff_ids', () {
    final json = fixtureMap('ticket_detail.json');
    final messages = json['messages']! as List;
    final withExtras = {
      ...json,
      'assignee_email': 'staff@example.test',
      'messages': [
        {...(messages.last as Map).cast<String, Object?>(), 'author': 'support', 'staff_id': 'secret-staff', 'author_name': 'Pat'},
        messages.first,
      ],
    };
    final thread = ticketThreadFromJson(withExtras);
    // The server's order is kept as sent (oldest first); the app never sorts it.
    expect(thread.messages.map((m) => m.author), [TicketAuthor.support, TicketAuthor.you]);
    // A message carries exactly an author, a text and a time: nothing a staff member is identified by.
    expect(thread.messages.first.props, hasLength(3));
    expect(thread.props.whereType<String>(), isNot(contains('staff@example.test')));
    expect(thread.messages.first.props, everyElement(isNot(isA<Map>())));
  });
}
