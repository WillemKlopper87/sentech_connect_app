import 'dart:convert';
import 'dart:math';

/// Makes the sign-in `binding`: a random secret that ties a login code to the
/// app instance that asked for it (backend P3, `docs/runbooks/customer-login.md`).
///
/// 32 bytes from the operating system's CSPRNG, base64url without padding:
/// 43 characters of `A-Z a-z 0-9 _ -` (the API wants 32 to 128 and at least 8
/// distinct characters). It must never be derived from the phone number, a
/// counter or the time. The value is kept in memory only, with the sign-in
/// attempt, and is never logged, stored on disk or put in a URL.
///
/// Inject a different [Random] (or a plain `String Function()` where one is
/// accepted) in tests only.
class BindingGenerator {
  BindingGenerator([Random? random]) : _random = random ?? Random.secure();

  static const byteLength = 32;
  static const minDistinctCharacters = 8;

  final Random _random;

  String call() {
    while (true) {
      final bytes = List<int>.generate(byteLength, (_) => _random.nextInt(256));
      final value = base64UrlEncode(bytes).replaceAll('=', '');
      // The API refuses fewer than 8 distinct characters; a CSPRNG all but never
      // produces that, but a broken source must not produce a weak binding.
      if (value.split('').toSet().length >= minDistinctCharacters) return value;
    }
  }
}
