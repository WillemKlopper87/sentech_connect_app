final _separators = RegExp(r'[\s\-().]');
final _mobile = RegExp(r'^(6\d|7\d|8[1-4])\d{7}$');

/// South African mobile number in E.164 (`+27821234567`), or null.
/// Accepts 0XX..., +27..., 0027... and 27... with spaces, dashes, dots or
/// brackets. Landlines (01x-05x) and 080/086/087 numbers are rejected; the
/// server checks again (`invalid_phone`).
String? normaliseZaMobile(String input) {
  final digits = input.trim().replaceAll(_separators, '');
  final String national;
  if (digits.startsWith('+27')) {
    national = digits.substring(3);
  } else if (digits.startsWith('0027')) {
    national = digits.substring(4);
  } else if (digits.startsWith('27') && digits.length == 11) {
    national = digits.substring(2);
  } else if (digits.startsWith('0') && digits.length == 10) {
    national = digits.substring(1);
  } else {
    return null;
  }
  return _mobile.hasMatch(national) ? '+27$national' : null;
}

/// `+27821234567` -> `+27 82 *** 4567` (for "we sent a code to ...").
String maskPhone(String e164) {
  if (!e164.startsWith('+27') || e164.length != 12) return e164;
  return '+27 ${e164.substring(3, 5)} *** ${e164.substring(8)}';
}
