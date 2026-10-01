import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/utils/phone_number.dart';

void main() {
  for (final (raw, expected) in [
    ('0821234567', '+27821234567'),
    ('082 123 4567', '+27821234567'),
    ('+27 82 123 4567', '+27821234567'),
    ('0027821234567', '+27821234567'),
    ('27821234567', '+27821234567'),
    ('  083-555-0123 ', '+27835550123'),
    ('(072) 123.4567', '+27721234567'),
    ('0611234567', '+27611234567'),
  ]) {
    test('normalises "$raw"', () => expect(normaliseZaMobile(raw), expected));
  }

  for (final raw in ['', '12345', 'abc', '+44 20 7946 0958', '011 123 4567', '0861234567', '0821234567821234567', '+27 82 123']) {
    test('rejects "$raw"', () => expect(normaliseZaMobile(raw), isNull));
  }

  test('masks the middle digits for display', () {
    expect(maskPhone('+27821234567'), '+27 82 *** 4567');
  });
}
