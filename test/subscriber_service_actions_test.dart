import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/subscriber_service.dart';
import 'package:sentech_connect_app/features/subscriber/domain/service_actions.dart';

import 'helpers/subscriber_service_fixtures.dart';

void main() {
  group('changePlanAvailability', () {
    test('active and suspended without a scheduled cancellation can change', () {
      expect(changePlanAvailability(testService()), ChangePlanAvailability.available);
      expect(
        changePlanAvailability(testService(status: ServiceStatus.suspended, suspendReason: SuspendReason.nonPayment)),
        ChangePlanAvailability.available,
      );
    });

    test('a scheduled cancellation blocks it, with an explanation', () {
      expect(
        changePlanAvailability(testService(cancelEffectiveOn: DateTime.utc(2026, 11, 30))),
        ChangePlanAvailability.blockedCancelling,
      );
    });

    test('pending is blocked with an explanation, cancelled is hidden', () {
      expect(changePlanAvailability(testService(status: ServiceStatus.pending)), ChangePlanAvailability.blockedInactive);
      expect(changePlanAvailability(testService(status: ServiceStatus.cancelled)), ChangePlanAvailability.hidden);
    });
  });

  group('cancelAvailability', () {
    test('active and suspended can be cancelled', () {
      expect(cancelAvailability(testService()), CancelAvailability.available);
      expect(
        cancelAvailability(testService(status: ServiceStatus.suspended, suspendReason: SuspendReason.admin)),
        CancelAvailability.available,
      );
    });

    test('pending says to contact support; scheduled and cancelled have no action', () {
      expect(cancelAvailability(testService(status: ServiceStatus.pending)), CancelAvailability.contactSupport);
      expect(cancelAvailability(testService(cancelEffectiveOn: DateTime.utc(2026, 11, 30))), CancelAvailability.hidden);
      expect(cancelAvailability(testService(status: ServiceStatus.cancelled)), CancelAvailability.hidden);
    });
  });

  group('planChangeTiming (sentence choice)', () {
    test('higher price switches now', () {
      expect(planChangeTiming(currentPriceCents: 12900, newPriceCents: 19900), PlanChangeTiming.immediate);
    });
    test('lower price is scheduled', () {
      expect(planChangeTiming(currentPriceCents: 19900, newPriceCents: 12900), PlanChangeTiming.scheduled);
    });
    test('equal price is scheduled (the platform applies only a strictly higher price at once)', () {
      expect(planChangeTiming(currentPriceCents: 19900, newPriceCents: 19900), PlanChangeTiming.scheduled);
    });
    test('an unknown current price makes no claim', () {
      expect(planChangeTiming(currentPriceCents: null, newPriceCents: 19900), PlanChangeTiming.unknown);
    });
  });

  group('dates', () {
    test('first of next month, including year end', () {
      expect(firstOfNextMonth(DateTime.utc(2026, 10, 30)), DateTime.utc(2026, 11, 1));
      expect(firstOfNextMonth(DateTime.utc(2026, 12, 31)), DateTime.utc(2027, 1, 1));
    });

    test('last day of the month at month ends, in a leap year and not', () {
      expect(lastDayOfMonth(DateTime.utc(2026, 1, 15)), DateTime.utc(2026, 1, 31));
      expect(lastDayOfMonth(DateTime.utc(2026, 4, 30)), DateTime.utc(2026, 4, 30));
      expect(lastDayOfMonth(DateTime.utc(2026, 2, 1)), DateTime.utc(2026, 2, 28));
      expect(lastDayOfMonth(DateTime.utc(2028, 2, 10)), DateTime.utc(2028, 2, 29));
      expect(lastDayOfMonth(DateTime.utc(2026, 12, 31)), DateTime.utc(2026, 12, 31));
    });

    test('the cancellation date is paid_through, else the last day of this month', () {
      expect(
        cancellationEndDate(testService(paidThrough: DateTime.utc(2026, 11, 30)), DateTime.utc(2026, 11, 3)),
        DateTime.utc(2026, 11, 30),
      );
      // Paid through is used as is, even when it is not a month end.
      expect(
        cancellationEndDate(testService(paidThrough: DateTime.utc(2026, 11, 14)), DateTime.utc(2026, 11, 3)),
        DateTime.utc(2026, 11, 14),
      );
      expect(cancellationEndDate(testService(), DateTime.utc(2028, 2, 10)), DateTime.utc(2028, 2, 29));
      expect(cancellationEndDate(testService(), DateTime.utc(2026, 2, 28)), DateTime.utc(2026, 2, 28));
    });
  });

  group('cancelReasonText', () {
    test('a choice alone, and a choice with text', () {
      expect(cancelReasonText(CancelReason.moving), 'Moving');
      expect(cancelReasonText(CancelReason.tooExpensive, '  Found a cheaper plan  '), 'Too expensive: Found a cheaper plan');
      expect(cancelReasonText(CancelReason.other, '   '), 'Other');
    });

    test('control characters and runs of spaces are cleaned, so the platform never refuses the text', () {
      expect(cancelReasonText(CancelReason.other, 'line one\nline\ttwo\u0000'), 'Other: line one line two');
    });

    test('the text is cut to 200 characters and stays trimmed', () {
      final text = cancelReasonText(CancelReason.other, 'x' * 500);
      expect(text.length, maxCancelReasonLength);
      expect(text, startsWith('Other: xxx'));
      final spaced = cancelReasonText(CancelReason.other, '${'a' * 192} bbb');
      expect(spaced.length, lessThanOrEqualTo(maxCancelReasonLength));
      expect(spaced, spaced.trim());
    });

    test('a cut never leaves half a surrogate pair', () {
      final text = cancelReasonText(CancelReason.other, '${'a' * 191}\u{1F600}\u{1F600}');
      expect(text.length, lessThanOrEqualTo(maxCancelReasonLength));
      final last = text.codeUnitAt(text.length - 1);
      expect(last >= 0xD800 && last <= 0xDBFF, isFalse);
    });
  });
}
