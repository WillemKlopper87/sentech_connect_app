import 'dart:math';

import 'package:sentech_connect_app/core/time/sast.dart';
import 'package:sentech_connect_app/features/fiveg_service/domain/entities/fiveg_usage.dart';

/// Warning band for [usedPercent]: below 50 is [UsageWarning.none]; 50 to 79
/// is p50, 80 to 99 is p80, 100 and above is p100. Null (no allowance) is none.
UsageWarning warningFor(int? usedPercent) {
  if (usedPercent == null || usedPercent < 50) return UsageWarning.none;
  if (usedPercent < 80) return UsageWarning.p50;
  if (usedPercent < 100) return UsageWarning.p80;
  return UsageWarning.p100;
}

/// Which headline the usage screen shows. [restoring] wins over the state:
/// an applied unlock is shown as restoring until the service is back.
enum UsageHeadline { normal, slowLane, cutOff, outOfBundle, fupThrottled, restoring }

UsageHeadline headlineFor(UsageState state, {required bool restoring}) {
  if (restoring) return UsageHeadline.restoring;
  return switch (state) {
    UsageState.normal => UsageHeadline.normal,
    UsageState.slowLane => UsageHeadline.slowLane,
    UsageState.cutOff => UsageHeadline.cutOff,
    UsageState.outOfBundle => UsageHeadline.outOfBundle,
    UsageState.fup => UsageHeadline.fupThrottled,
  };
}

/// The day the allowance resets: the day after [cycleEnd].
DateTime resetDayFor(DateTime cycleEnd) => nextCalendarDay(cycleEnd);

/// Whole days from [today] (a SAST calendar day, see `sastDay`) until the
/// reset. On the last day of a cycle that is 1; on the reset day it is 0.
int daysUntilReset(DateTime cycleEnd, DateTime today) => max(0, calendarDaysBetween(today, resetDayFor(cycleEnd)));

/// The last day of the calendar month that [day] falls in.
DateTime lastDayOfMonth(DateTime day) => DateTime.utc(day.year, day.month + 1, 0);

/// A megabyte count as text with decimal units: 500 becomes "500 MB", 1500
/// becomes "1.5 GB", 100000 becomes "100 GB" and 1000000 becomes "1 TB".
String formatDataSize(int megabytes) {
  if (megabytes < 1000) return '$megabytes MB';
  if (megabytes < 1000000) return '${_tenths(megabytes, 1000)} GB';
  return '${_tenths(megabytes, 1000000)} TB';
}

/// [value] divided by [unit] to one decimal place, without a trailing ".0".
String _tenths(int value, int unit) {
  final tenths = (value * 10 / unit).round();
  final whole = tenths ~/ 10;
  final fraction = tenths % 10;
  return fraction == 0 ? '$whole' : '$whole.$fraction';
}
