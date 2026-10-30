import 'package:sentech_connect_app/core/utils/phone_number.dart';

/// Client checks that mirror the platform schema (`AccountProfilePatchIn` /
/// `ProfileUpdateIn`); the platform stays the authority.
final _email = RegExp(r'^[^@\s]{1,64}@[^@\s]{1,189}\.[^@\s]{2,}$');

/// The trimmed name when it is 1..[max] characters, else null.
String? validName(String raw, {int max = 120}) {
  final v = raw.trim();
  return v.isEmpty || v.length > max ? null : v;
}

/// The trimmed email when it fits the platform pattern (max 254), else null.
String? validEmail(String raw) {
  final v = raw.trim();
  return v.length <= 254 && _email.hasMatch(v) ? v : null;
}

/// E.164 for a South African mobile number, else null.
String? validPhone(String raw) => normaliseZaMobile(raw);
