import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/time/sast.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/usage_levels.dart';

void main() {
  group('warningFor (50, 80, 100 percent bands)', () {
    test('below 50 is no warning, at the edges of each band', () {
      expect(warningFor(null), UsageWarning.none);
      expect(warningFor(0), UsageWarning.none);
      expect(warningFor(49), UsageWarning.none);
      expect(warningFor(50), UsageWarning.p50);
      expect(warningFor(79), UsageWarning.p50);
      expect(warningFor(80), UsageWarning.p80);
      expect(warningFor(99), UsageWarning.p80);
      expect(warningFor(100), UsageWarning.p100);
      expect(warningFor(140), UsageWarning.p100);
    });
  });

  group('headlineFor', () {
    test('maps each platform state to its own headline', () {
      expect(headlineFor(UsageState.normal, restoring: false), UsageHeadline.normal);
      expect(headlineFor(UsageState.slowLane, restoring: false), UsageHeadline.slowLane);
      expect(headlineFor(UsageState.cutOff, restoring: false), UsageHeadline.cutOff);
      expect(headlineFor(UsageState.outOfBundle, restoring: false), UsageHeadline.outOfBundle);
      expect(headlineFor(UsageState.fup, restoring: false), UsageHeadline.fupThrottled);
    });

    test('restoring wins over the state while a paid unlock is being applied', () {
      for (final state in UsageState.values) {
        expect(headlineFor(state, restoring: true), UsageHeadline.restoring, reason: '$state');
      }
    });
  });

  group('reset day and days left (SAST calendar days)', () {
    test('the day after the cycle end is the reset day', () {
      expect(resetDayFor(DateTime.utc(2026, 11, 30)), DateTime.utc(2026, 12, 1));
    });

    test('on the last day of a cycle there is 1 day left', () {
      expect(daysUntilReset(DateTime.utc(2026, 11, 30), DateTime.utc(2026, 11, 30)), 1);
    });

    test('earlier in the cycle counts down', () {
      expect(daysUntilReset(DateTime.utc(2026, 11, 30), DateTime.utc(2026, 11, 10)), 21);
    });

    test('on the reset day there are 0 days left, never negative', () {
      expect(daysUntilReset(DateTime.utc(2026, 11, 30), DateTime.utc(2026, 12, 1)), 0);
      expect(daysUntilReset(DateTime.utc(2026, 11, 30), DateTime.utc(2026, 12, 15)), 0);
    });

    test('year end: 31 December resets on 1 January', () {
      expect(resetDayFor(DateTime.utc(2026, 12, 31)), DateTime.utc(2027, 1, 1));
      expect(daysUntilReset(DateTime.utc(2026, 12, 31), DateTime.utc(2026, 12, 31)), 1);
    });

    test('leap day: a cycle ending 29 February resets on 1 March', () {
      expect(resetDayFor(DateTime.utc(2028, 2, 29)), DateTime.utc(2028, 3, 1));
      expect(daysUntilReset(DateTime.utc(2028, 2, 29), DateTime.utc(2028, 2, 28)), 2);
    });

    test('the day is read in South Africa time: 23:30 UTC on 30 Nov is already 1 Dec in SAST', () {
      final instant = DateTime.utc(2026, 11, 30, 23, 30);
      expect(sastDay(instant), DateTime.utc(2026, 12, 1));
      expect(daysUntilReset(DateTime.utc(2026, 11, 30), sastDay(instant)), 0);
    });

    test('just before SAST midnight it is still the last day of the cycle', () {
      final instant = DateTime.utc(2026, 11, 30, 21, 59);
      expect(sastDay(instant), DateTime.utc(2026, 11, 30));
    });
  });

  group('formatDataSize (decimal units)', () {
    test('megabytes below one gigabyte', () {
      expect(formatDataSize(0), '0 MB');
      expect(formatDataSize(500), '500 MB');
      expect(formatDataSize(999), '999 MB');
    });

    test('gigabytes, with at most one decimal and no trailing .0', () {
      expect(formatDataSize(1000), '1 GB');
      expect(formatDataSize(1500), '1.5 GB');
      expect(formatDataSize(1250), '1.3 GB');
      expect(formatDataSize(50000), '50 GB');
      expect(formatDataSize(100000), '100 GB');
      expect(formatDataSize(500000), '500 GB');
    });

    test('terabytes from 1000 GB', () {
      expect(formatDataSize(1000000), '1 TB');
      expect(formatDataSize(1500000), '1.5 TB');
    });
  });

  test('the last day of a month is found for 28, 30 and 31 day months and February 2028', () {
    expect(lastDayOfMonth(DateTime.utc(2026, 2, 10)), DateTime.utc(2026, 2, 28));
    expect(lastDayOfMonth(DateTime.utc(2026, 4, 1)), DateTime.utc(2026, 4, 30));
    expect(lastDayOfMonth(DateTime.utc(2026, 12, 9)), DateTime.utc(2026, 12, 31));
    expect(lastDayOfMonth(DateTime.utc(2028, 2, 1)), DateTime.utc(2028, 2, 29));
  });
}
