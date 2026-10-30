import 'package:sentech_connect_app/features/subscriber/domain/entities/kyc.dart';

/// Client-side mirror of the platform's identity rules
/// (`subscribers/kyc.py: validate_id_number`, `kyc.submit_kyc`), so the form
/// can say "check your ID number" before anything is sent. The platform stays
/// the authority: it answers 422 `invalid_identity_number` / `invalid_address`
/// for anything this lets through. Pure functions, no personal data kept.
abstract final class KycValidators {
  static const maxAddressLength = 2000;

  /// Characters the platform refuses in any text field: control characters
  /// (newline and tab included, at the request schema level) and bidi
  /// overrides.
  static final forbidden = RegExp(r'[\u0000-\u001f\u007f-\u009f\u202a-\u202e\u2066-\u2069]');

  /// What the id-number field may contain at all, per type (used by the input
  /// formatter; validity is [isValidIdNumber]).
  static bool isAllowedChar(KycIdType type, String char) => switch (type) {
    KycIdType.saId => RegExp(r'^[0-9]$').hasMatch(char),
    KycIdType.passport => RegExp(r'^[A-Za-z0-9]$').hasMatch(char),
    KycIdType.companyReg => RegExp(r'^[0-9/]$').hasMatch(char),
  };

  static int maxFieldLength(KycIdType type) => switch (type) {
    KycIdType.saId => 13,
    KycIdType.passport => 12,
    KycIdType.companyReg => 14, // 1234/123456/12
  };

  /// Trims, and upper-cases a passport number as the platform does.
  static String normalizeIdNumber(KycIdType type, String raw) {
    final value = raw.trim();
    return type == KycIdType.passport ? value.toUpperCase() : value;
  }

  /// [todayInSast] is the calendar date in Africa/Johannesburg (only year,
  /// month and day are read); see [sastDate].
  static bool isValidIdNumber(KycIdType type, String raw, DateTime todayInSast) {
    final value = normalizeIdNumber(type, raw);
    switch (type) {
      case KycIdType.passport:
        return RegExp(r'^[A-Za-z0-9]{6,12}$').hasMatch(value);
      case KycIdType.companyReg:
        return RegExp(r'^[0-9]{4}/[0-9]{6}/[0-9]{2}$').hasMatch(value);
      case KycIdType.saId:
        if (!RegExp(r'^[0-9]{13}$').hasMatch(value)) return false;
        final yy = int.parse(value.substring(0, 2));
        final month = int.parse(value.substring(2, 4));
        final day = int.parse(value.substring(4, 6));
        // Latest non-future century, as the platform does.
        var year = (todayInSast.year ~/ 100) * 100 + yy;
        if (_after(year, month, day, todayInSast)) year -= 100;
        final built = DateTime.utc(year, month, day);
        if (built.year != year || built.month != month || built.day != day) return false;
        // Digit 11 is the citizenship flag (0 or 1); the last digit is a Luhn check.
        if (value[10] != '0' && value[10] != '1') return false;
        return _luhn(value);
    }
  }

  static bool _after(int year, int month, int day, DateTime today) {
    if (year != today.year) return year > today.year;
    if (month != today.month) return month > today.month;
    return day > today.day;
  }

  static bool _luhn(String digits) {
    var total = 0;
    for (var i = 0; i < digits.length; i++) {
      var n = int.parse(digits[digits.length - 1 - i]);
      if (i.isOdd) {
        n *= 2;
        if (n > 9) n -= 9;
      }
      total += n;
    }
    return total % 10 == 0;
  }

  /// The address as sent: every run of whitespace or control characters
  /// becomes one space (the platform stores it the same way, and it refuses a
  /// raw newline), then trimmed.
  static String normalizeAddress(String raw) =>
      raw.replaceAll(forbidden, ' ').split(RegExp(r'\s+')).where((p) => p.isNotEmpty).join(' ');

  static bool isValidAddress(String raw) {
    final value = normalizeAddress(raw);
    return value.isNotEmpty && value.length <= maxAddressLength;
  }

  /// The calendar date in Africa/Johannesburg (UTC+2, no daylight saving) for
  /// an instant, as a UTC date with no time.
  static DateTime sastDate(DateTime instant) {
    final sast = instant.toUtc().add(const Duration(hours: 2));
    return DateTime.utc(sast.year, sast.month, sast.day);
  }
}
