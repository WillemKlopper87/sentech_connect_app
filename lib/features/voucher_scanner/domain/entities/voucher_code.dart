import 'package:equatable/equatable.dart';

/// Why typed or scanned text is not a voucher code, so the UI can say what
/// to fix without sending a request the server would refuse anyway.
enum VoucherCodeProblem {
  /// Not letters, digits, spaces and dashes (or a bad display prefix).
  format,

  /// Wrong number of symbols.
  length,

  /// Uses a character codes never contain (0, 1, I, L, O, U).
  notInAlphabet,

  /// Well-formed, but the check symbol does not match: almost always a typo.
  checkSymbol,
}

/// A voucher code the platform would accept. Mirrors the server's
/// `normalise_code` (apps/api/src/sentech_api/modules/vouchers/codes.py)
/// exactly, so the app is never stricter (a real voucher refused on the
/// device) nor looser (a request for a code that cannot exist):
///
/// - upper-case, then remove every run of whitespace and dashes;
/// - 12 to 17 symbols: an optional display prefix of 2-5 letters (`SEN-`),
///   then the 12-symbol payload;
/// - the payload uses only [alphabet] (no 0/O, 1/I/L or U) and its last
///   symbol is the Luhn mod 30 check symbol of the first 11.
///
/// Ambiguous characters are refused, not guessed: the server does not map
/// them either.
///
/// Being a valid [VoucherCode] says nothing about whether the voucher exists
/// or is unused; only the server can decide that.
class VoucherCode extends Equatable {
  const VoucherCode._(this.value);

  static const alphabet = '23456789ABCDEFGHJKMNPQRSTVWXYZ';
  static const payloadLength = 12;
  static const _maxPrefix = 5;

  static final _separators = RegExp(r'[\s-]+');
  static final _symbols = RegExp(r'^[A-Z0-9]+$');
  static final _prefix = RegExp(r'^[A-Z]{2,5}$');

  /// The pre-M2 demo format, honoured only by the demo flavor's mock.
  static final _legacyDemo = RegExp(r'^SEN[A-Z0-9]{8}$');

  /// What is sent to the server: the 12-symbol payload (the display prefix
  /// is never part of the voucher), or `SEN-XXXX-XXXX` for a demo code.
  final String value;

  bool get isLegacyDemo => value.startsWith('SEN-');

  /// Returns null unless the server would accept [raw]. [allowDemo] also
  /// accepts the demo flavor's `SEN-XXXX-XXXX` codes.
  static VoucherCode? tryParse(String? raw, {bool allowDemo = false}) =>
      _parse(raw, allowDemo).code;

  /// Null when [raw] parses; otherwise why it does not.
  static VoucherCodeProblem? problemWith(
    String? raw, {
    bool allowDemo = false,
  }) => _parse(raw, allowDemo).problem;

  static ({VoucherCode? code, VoucherCodeProblem? problem}) _parse(
    String? raw,
    bool allowDemo,
  ) {
    const format = (code: null, problem: VoucherCodeProblem.format);
    // Reject oversized payloads (e.g. a QR carrying a long URL) before any
    // normalisation work.
    if (raw == null || raw.length > 200) return format;
    var text = raw;
    // A scanned voucher QR is a /redeem link whose fragment is
    // `t=<tenant>&c=<code>` (the web's parseRedeemFragment). Only `c` is used:
    // the tenant is always the app's own.
    final hash = text.indexOf('#');
    if (hash >= 0) {
      try {
        text = Uri.splitQueryString(text.substring(hash + 1))['c'] ?? '';
      } on FormatException {
        return format;
      }
    }
    final s = text.toUpperCase().replaceAll(_separators, '');
    if (s.isEmpty || !_symbols.hasMatch(s)) return format;
    if (allowDemo && _legacyDemo.hasMatch(s)) {
      return (
        code: VoucherCode._('SEN-${s.substring(3, 7)}-${s.substring(7)}'),
        problem: null,
      );
    }
    if (s.length < payloadLength || s.length > payloadLength + _maxPrefix) {
      return (code: null, problem: VoucherCodeProblem.length);
    }
    final prefix = s.substring(0, s.length - payloadLength);
    final payload = s.substring(s.length - payloadLength);
    if (prefix.isNotEmpty && !_prefix.hasMatch(prefix)) return format;
    if (payload.split('').any((c) => !alphabet.contains(c))) {
      return (code: null, problem: VoucherCodeProblem.notInAlphabet);
    }
    if (checkSymbol(payload.substring(0, payloadLength - 1)) !=
        payload[payloadLength - 1]) {
      return (code: null, problem: VoucherCodeProblem.checkSymbol);
    }
    return (code: VoucherCode._(payload), problem: null);
  }

  /// Luhn mod N over [alphabet], as the server's `check_symbol`: catches
  /// every single-symbol substitution and most transpositions.
  static String checkSymbol(String body) {
    final n = alphabet.length;
    var factor = 2;
    var total = 0;
    for (final ch in body.split('').reversed) {
      final addend = factor * alphabet.indexOf(ch);
      factor = factor == 2 ? 1 : 2;
      total += addend ~/ n + addend % n;
    }
    return alphabet[(n - total % n) % n];
  }

  /// Grouped as the voucher card prints it: `ABCD-2345-EFGH`.
  String get display => isLegacyDemo
      ? value
      : '${value.substring(0, 4)}-${value.substring(4, 8)}-${value.substring(8)}';

  /// Safe-to-display form, e.g. `••••-••••-••GH` (`SEN-••••-••LM` for a
  /// demo code).
  String get masked {
    final tail = value.substring(value.length - 2);
    return isLegacyDemo ? 'SEN-••••-••$tail' : '••••-••••-••$tail';
  }

  @override
  List<Object?> get props => [value];
}
