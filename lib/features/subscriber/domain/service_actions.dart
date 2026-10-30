import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';

/// Rules for the two customer actions on a service (change plan, cancel at
/// period end). Pure functions so the screens only render the answer.

/// Whether the customer may change plan, or why not.
enum ChangePlanAvailability {
  /// Offer the action.
  available,

  /// `cancel_effective_on` is set: "Not available while cancellation is scheduled".
  blockedCancelling,

  /// Pending service: "Available once your service is active".
  blockedInactive,

  /// Ended: no explanation, the action is simply absent.
  hidden,
}

/// Mirrors the platform: only `active` or `suspended` services with no
/// scheduled cancellation can change plan.
ChangePlanAvailability changePlanAvailability(SubscriberService service) {
  switch (service.status) {
    case ServiceStatus.cancelled:
      return ChangePlanAvailability.hidden;
    case ServiceStatus.pending:
      return ChangePlanAvailability.blockedInactive;
    case ServiceStatus.active:
    case ServiceStatus.suspended:
      return service.isCancellationScheduled
          ? ChangePlanAvailability.blockedCancelling
          : ChangePlanAvailability.available;
  }
}

/// Whether the customer may cancel, or what to show instead.
enum CancelAvailability {
  /// Offer the action.
  available,

  /// Pending service: the platform refuses (409 `pending_requires_immediate_cancellation`).
  contactSupport,

  /// Already scheduled, or ended: no action (the banner says "Ends on ...").
  hidden,
}

CancelAvailability cancelAvailability(SubscriberService service) {
  switch (service.status) {
    case ServiceStatus.cancelled:
      return CancelAvailability.hidden;
    case ServiceStatus.pending:
      return CancelAvailability.contactSupport;
    case ServiceStatus.active:
    case ServiceStatus.suspended:
      return service.isCancellationScheduled ? CancelAvailability.hidden : CancelAvailability.available;
  }
}

/// What a plan change will do, from the price comparison the platform makes
/// (`applied = new price > price of the service's current version`).
enum PlanChangeTiming {
  /// New price is higher: switches now, the difference is invoiced.
  immediate,

  /// Same or lower price: takes effect on the first of next month.
  scheduled,

  /// Current price unknown: say nothing about timing.
  unknown,
}

PlanChangeTiming planChangeTiming({required int? currentPriceCents, required int newPriceCents}) {
  if (currentPriceCents == null || currentPriceCents < 0) return PlanChangeTiming.unknown;
  return newPriceCents > currentPriceCents ? PlanChangeTiming.immediate : PlanChangeTiming.scheduled;
}

/// First day of the month after [today] (a plain calendar date, UTC marker).
DateTime firstOfNextMonth(DateTime today) => DateTime.utc(today.year, today.month + 1, 1);

/// Last day of [today]'s month.
DateTime lastDayOfMonth(DateTime today) => DateTime.utc(today.year, today.month + 1, 0);

/// The day a cancellation will take effect, as the platform computes it:
/// `paid_through`, else the last day of the current month.
DateTime cancellationEndDate(SubscriberService service, DateTime today) =>
    service.paidThrough ?? lastDayOfMonth(today);

/// The reasons offered when cancelling. The text sent to the platform is
/// always English (provider staff read it), whatever the app language.
enum CancelReason {
  moving('Moving'),
  tooExpensive('Too expensive'),
  notReliable('Not reliable'),
  other('Other');

  const CancelReason(this.apiText);

  final String apiText;
}

const maxCancelReasonLength = 200;

final _controlChars = RegExp(r'[\u0000-\u001F\u007F-\u009F]');

/// `"<choice>: <text>"` (just the choice when there is no text), trimmed,
/// control characters turned into spaces, and cut to 200 characters without
/// leaving half of a surrogate pair at the end.
String cancelReasonText(CancelReason reason, [String? detail]) {
  final cleanDetail = (detail ?? '').replaceAll(_controlChars, ' ').replaceAll(RegExp(r' {2,}'), ' ').trim();
  final full = cleanDetail.isEmpty ? reason.apiText : '${reason.apiText}: $cleanDetail';
  if (full.length <= maxCancelReasonLength) return full;
  var end = maxCancelReasonLength;
  final last = full.codeUnitAt(end - 1);
  if (last >= 0xD800 && last <= 0xDBFF) end--;
  return full.substring(0, end).trim();
}
