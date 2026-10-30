/// The platform's `date` fields (`paid_through`, `due_date`, ...) are business
/// dates in Africa/Johannesburg with no time and no zone. They are parsed to
/// a plain calendar date and never shifted: `DateTime.parse('2026-11-01')`
/// would be local midnight, and converting that to UTC or back is exactly the
/// off-by-one near midnight this helper exists to avoid. Show only year,
/// month and day from the result.
final _apiDate = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

/// `YYYY-MM-DD` -> a [DateTime.utc] at 00:00 on that calendar day (UTC only
/// so the value is stable and comparable; read [DateTime.year], [DateTime.month]
/// and [DateTime.day], never convert it to local time). Throws [FormatException]
/// for anything else, including impossible dates such as `2026-02-30`.
DateTime parseApiDate(String value) {
  final m = _apiDate.firstMatch(value);
  if (m == null) throw FormatException('Not an API date: $value');
  final year = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final day = int.parse(m.group(3)!);
  final parsed = DateTime.utc(year, month, day);
  if (parsed.year != year || parsed.month != month || parsed.day != day) {
    throw FormatException('Not a calendar date: $value');
  }
  return parsed;
}

/// [parseApiDate] for a nullable field.
DateTime? parseApiDateOrNull(Object? value) => value == null ? null : parseApiDate(value as String);

/// A [DateTime] back to the `YYYY-MM-DD` the API speaks (year, month and day
/// as stored, no zone conversion).
String formatApiDate(DateTime date) =>
    '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
