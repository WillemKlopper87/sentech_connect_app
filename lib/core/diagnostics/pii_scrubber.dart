/// Removes personal data from text before it leaves the device in a crash
/// report or log line (POPIA: error reports must not carry customer data).
///
/// This is a safety net, not a licence to log PII: prefer never putting
/// personal data into exception messages in the first place.
class PiiScrubber {
  PiiScrubber._();

  static final _rules = <(RegExp, String)>[
    // Email addresses.
    (RegExp(r'[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}'), '[email]'),
    // Sentech voucher codes.
    (RegExp(r'\bSEN-[A-Za-z0-9]{4}-[A-Za-z0-9]{4}\b', caseSensitive: false), '[voucher]'),
    // Bearer / authorization tokens.
    (RegExp(r'Bearer\s+[A-Za-z0-9._~+/\-]+=*', caseSensitive: false), 'Bearer [token]'),
    // South African mobile/landline numbers: 0XX XXX XXXX, +27 XX XXX XXXX, 0027...
    (RegExp(r'(?:\+27|0027|\b0)[\s\-]?\d{2}[\s\-]?\d{3}[\s\-]?\d{4}\b'), '[phone]'),
    // South African ID numbers (13 digits) and other long digit runs
    // (card numbers, account numbers).
    (RegExp(r'\b\d{13,19}\b'), '[number]'),
    // Decimal coordinates with 4+ decimals, e.g. -26.205871 / 28.049722.
    (RegExp(r'(?<![\d.])-?\d{1,3}\.\d{4,}(?!\d)'), '[coord]'),
    // Long opaque strings: API keys, session/refresh tokens, hashes.
    (RegExp(r'\b[A-Za-z0-9_\-]{32,}\b'), '[token]'),
  ];

  /// `binding`, one-time `code`s, the human-check `turnstile_token` and session
  /// tokens in JSON or `key=value` text: the value goes whatever it looks like
  /// (a 6-digit code would pass every other rule).
  static final _secretFields = RegExp(
    r'''(["']?(?<![A-Za-z_])(?:binding|code|turnstile_token|refresh_token|access_token)["']?\s*[:=]\s*["']?)[^"'\s,&})\]]+''',
    caseSensitive: false,
  );

  static String scrub(String input) {
    var out = input.replaceAllMapped(_secretFields, (m) => '${m[1]}[redacted]');
    for (final (pattern, replacement) in _rules) {
      out = out.replaceAll(pattern, replacement);
    }
    return out;
  }
}
