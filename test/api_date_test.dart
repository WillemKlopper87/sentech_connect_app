import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/time/api_date.dart';

void main() {
  test('a date is the same calendar day whatever the zone of the phone', () {
    final d = parseApiDate('2026-11-01');
    expect((d.year, d.month, d.day), (2026, 11, 1));
    expect(d.isUtc, isTrue);
    expect(d.hour, 0);
  });

  test('a round trip returns the same text', () {
    for (final s in ['2026-01-31', '2024-02-29', '2026-12-31']) {
      expect(formatApiDate(parseApiDate(s)), s);
    }
  });

  test('dates compare by day', () {
    expect(parseApiDate('2026-11-30').isAfter(parseApiDate('2026-11-01')), isTrue);
    expect(parseApiDate('2026-11-01'), parseApiDate('2026-11-01'));
  });

  test('anything that is not YYYY-MM-DD is refused', () {
    for (final bad in ['', '2026-1-1', '2026-11-01T00:00:00Z', '01/11/2026', '2026-13-01', '2026-02-30', '2026-11-31']) {
      expect(() => parseApiDate(bad), throwsFormatException, reason: bad);
    }
  });

  test('null stays null', () {
    expect(parseApiDateOrNull(null), isNull);
    expect(parseApiDateOrNull('2026-11-01'), parseApiDate('2026-11-01'));
  });
}
