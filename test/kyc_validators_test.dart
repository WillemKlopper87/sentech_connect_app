import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';
import 'package:sentech_connect_app/features/subscriber/domain/kyc/kyc_validators.dart';
import 'package:sentech_connect_app/features/subscriber/presentation/kyc/id_number_formatter.dart';

final _today = DateTime.utc(2026, 10, 30);
bool _ok(KycIdType t, String v) => KycValidators.isValidIdNumber(t, v, _today);

/// Builds a 13-digit SA ID from 10 leading digits + citizenship 0 + race 8 + Luhn digit.
String _withLuhn(String first10) {
  final partial = '${first10}08';
  for (var c = 0; c < 10; c++) {
    final candidate = '$partial$c';
    var total = 0;
    for (var i = 0; i < candidate.length; i++) {
      var n = int.parse(candidate[candidate.length - 1 - i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      total += n;
    }
    if (total % 10 == 0) return candidate;
  }
  throw StateError('no check digit');
}

void main() {
  group('SA ID', () {
    test('accepts a well-formed number (date, citizenship digit, Luhn)', () {
      expect(_ok(KycIdType.saId, '8001015009087'), isTrue);
      expect(_ok(KycIdType.saId, ' 8001015009087 '), isTrue, reason: 'trimmed as the platform does');
    });

    test('rejects wrong length, letters, bad checksum, bad date, bad citizenship digit', () {
      for (final bad in [
        '',
        '800101500908',
        '80010150090871',
        '800101500908A',
        '8001015009088', // Luhn
        '8002305009087', // 30 Feb
        '8013015009087', // month 13
        '8001015019087', // digit 11 must be 0 or 1
      ]) {
        expect(_ok(KycIdType.saId, bad), isFalse, reason: bad);
      }
    });

    test('century, leap days and the citizenship digit', () {
      // 311231 is 2031-12-31 (future), so it reads as 1931-12-31.
      expect(_ok(KycIdType.saId, _withLuhn('3112310000')), isTrue);
      expect(_ok(KycIdType.saId, _withLuhn('0002290000')), isTrue, reason: '2000 was a leap year');
      expect(_ok(KycIdType.saId, _withLuhn('0102290000')), isFalse, reason: '2001 was not');
      expect(_ok(KycIdType.saId, _withLuhn('2601010000')), isTrue);
    });
  });

  test('passport is 6 to 12 letters or digits and is upper-cased', () {
    expect(_ok(KycIdType.passport, 'a1234567'), isTrue);
    expect(KycValidators.normalizeIdNumber(KycIdType.passport, ' a1234567 '), 'A1234567');
    for (final bad in ['A123', 'A1234567890123', 'A12 3456', 'A1234-567']) {
      expect(_ok(KycIdType.passport, bad), isFalse, reason: bad);
    }
  });

  test('company registration is NNNN/NNNNNN/NN', () {
    expect(_ok(KycIdType.companyReg, '2015/123456/07'), isTrue);
    for (final bad in ['2015123456 07', '2015/12345/07', '2015/123456/7', 'ABCD/123456/07']) {
      expect(_ok(KycIdType.companyReg, bad), isFalse, reason: bad);
    }
  });

  group('address', () {
    test('control characters and runs of space become single spaces, then trimmed', () {
      expect(KycValidators.normalizeAddress('  1 Main Road\n Sandton\t\t2196  '), '1 Main Road Sandton 2196');
    });
    test('empty or over 2000 characters is invalid', () {
      expect(KycValidators.isValidAddress('  \n '), isFalse);
      expect(KycValidators.isValidAddress('x' * 2000), isTrue);
      expect(KycValidators.isValidAddress('x' * 2001), isFalse);
    });
  });

  test('SAST date is UTC+2', () {
    expect(KycValidators.sastDate(DateTime.utc(2026, 10, 29, 22, 30)), DateTime.utc(2026, 10, 30));
    expect(KycValidators.sastDate(DateTime.utc(2026, 10, 29, 21, 59)), DateTime.utc(2026, 10, 29));
  });

  group('input formatter', () {
    TextEditingValue run(KycIdType t, String text) =>
        IdNumberFormatter(t).formatEditUpdate(TextEditingValue.empty, TextEditingValue(text: text));

    test('SA ID keeps digits only, max 13', () {
      expect(run(KycIdType.saId, '80 01-01a5009087999').text, '8001015009087');
    });
    test('passport is upper-case alphanumeric, max 12', () {
      expect(run(KycIdType.passport, 'a12-34 5678901234').text, 'A12345678901');
    });
    test('company registration gets its slashes while typing', () {
      expect(run(KycIdType.companyReg, '2015').text, '2015');
      expect(run(KycIdType.companyReg, '20151').text, '2015/1');
      expect(run(KycIdType.companyReg, '2015123456').text, '2015/123456');
      expect(run(KycIdType.companyReg, '201512345607').text, '2015/123456/07');
      expect(run(KycIdType.companyReg, '2015/123456/07999').text, '2015/123456/07');
    });
  });
}
