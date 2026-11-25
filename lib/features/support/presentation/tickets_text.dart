import 'package:intl/intl.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/features/support/domain/entities/incident.dart';
import 'package:sentech_connect_app/features/support/domain/entities/ticket.dart';
import 'package:sentech_connect_app/features/support/presentation/bloc/new_ticket_cubit.dart';
import 'package:sentech_connect_app/l10n/app_localizations.dart';
import 'package:sentech_connect_app/l10n/failure_copy.dart';

/// The words for a ticket status. A status the app does not know gets a
/// neutral label: never "solved" or "closed" on a guess.
String ticketStatusLabel(AppLocalizations l10n, TicketStatus status) => switch (status) {
  TicketStatus.newTicket => l10n.ticketStatusNew,
  TicketStatus.open => l10n.ticketStatusOpen,
  TicketStatus.pendingCustomer => l10n.ticketStatusPendingCustomer,
  TicketStatus.onHold => l10n.ticketStatusOnHold,
  TicketStatus.resolved => l10n.ticketStatusResolved,
  TicketStatus.closed => l10n.ticketStatusClosed,
  TicketStatus.unknown => l10n.ticketStatusUnknown,
};

/// The provider's category name, or a neutral word when the server sent none.
String ticketCategoryLabel(AppLocalizations l10n, Ticket ticket) =>
    ticket.categoryName.isEmpty ? l10n.ticketsCategoryFallback : ticket.categoryName;

String ticketAuthorLabel(AppLocalizations l10n, TicketAuthor author) => switch (author) {
  TicketAuthor.you => l10n.ticketsAuthorYou,
  TicketAuthor.support => l10n.ticketsAuthorSupport,
  TicketAuthor.unknown => l10n.ticketsAuthorOther,
};

String incidentSeverityLabel(AppLocalizations l10n, IncidentSeverity severity) => switch (severity) {
  IncidentSeverity.degraded => l10n.ticketsIncidentDegraded,
  IncidentSeverity.outage => l10n.ticketsIncidentOutage,
  IncidentSeverity.info || IncidentSeverity.unknown => l10n.ticketsIncidentInfo,
};

String ticketIssueMessage(AppLocalizations l10n, NewTicketIssue issue, int max) => switch (issue) {
  NewTicketIssue.noCategory => l10n.ticketsNewIssueNoCategory,
  NewTicketIssue.bodyEmpty => l10n.ticketsNewIssueEmpty,
  NewTicketIssue.bodyTooLong => l10n.ticketsNewIssueTooLong(max),
};

/// Customer text for a failed ticket call. The typed refusals come from the
/// shared failure copy; offline and server errors reuse the generic request copy.
String ticketFailureMessage(AppLocalizations l10n, Failure? failure) {
  final typed = typedFailureText(l10n, failure);
  if (typed != null) return typed;
  return switch (failure) {
    NetworkFailure() => l10n.accountRequestOffline,
    RateLimitedFailure() => l10n.accountRequestRateLimited,
    _ => l10n.accountRequestFailed,
  };
}

/// "5 minutes" or "30 seconds", rounded up so the customer never retries early.
String ticketWaitText(AppLocalizations l10n, Duration wait) {
  final seconds = wait.inSeconds + (wait.inMilliseconds % 1000 == 0 ? 0 : 1);
  if (seconds <= 90) return l10n.ticketsWaitSeconds(seconds < 1 ? 1 : seconds);
  return l10n.ticketsWaitMinutes((seconds / 60).ceil());
}

String ticketDate(String localeTag, DateTime time) => DateFormat.yMMMd(localeTag).format(time.toLocal());

String ticketDateTime(String localeTag, DateTime time) => DateFormat.yMMMd(localeTag).add_Hm().format(time.toLocal());
