/// South Africa Standard Time (Africa/Johannesburg): UTC+2 all year, no
/// daylight saving. Use these helpers for every "which calendar day is it
/// for the customer" question instead of adding +2 hours inline.
const sastOffset = Duration(hours: 2);

/// The SAST calendar day of [instant], as a [DateTime.utc] at midnight, so
/// only its year, month and day are meaningful (the same convention as
/// `parseApiDate`).
DateTime sastDay(DateTime instant) {
  final local = instant.toUtc().add(sastOffset);
  return DateTime.utc(local.year, local.month, local.day);
}

/// The calendar day after [day]. Handles month, year and leap-day ends.
DateTime nextCalendarDay(DateTime day) => DateTime.utc(day.year, day.month, day.day + 1);

/// Whole calendar days from [from] to [to] (both plain dates, no time zone).
int calendarDaysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;
