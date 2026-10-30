import 'package:flutter/foundation.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';

/// A bad Turnstile build define stops the app at startup like a bad API URL
/// (main.dart shows the start-up error screen).
class InvalidTurnstileConfig extends InvalidEnvironment {
  const InvalidTurnstileConfig(super.message);

  @override
  String toString() => 'InvalidTurnstileConfig: $message';
}

/// What the Turnstile WebView needs. **Precedence: the API wins.** The values
/// come from `GET /v1/auth/human-check/config` (see `HumanCheckGate`); only
/// when that route fails do these build values apply:
///
///  * `--dart-define=TURNSTILE_SITE_KEY=0x4AAAA...` the PUBLIC site key of the
///    Cloudflare Turnstile widget (never the secret key);
///  * `--dart-define=TURNSTILE_BASE_URL=https://www.example.co.za` the origin
///    the widget page claims to be served from. The platform's
///    `TurnstileVerifier` accepts a token only when Cloudflare reports a
///    hostname equal to (or a subdomain of) `SENTECH_TURNSTILE_ALLOWED_HOSTNAMES`
///    (default in staging and prod: the public web hostname), and the Turnstile
///    widget must list the same hostname. So this is the platform's public web
///    origin, not the API origin.
@immutable
class TurnstileConfig {
  const TurnstileConfig({required this.siteKey, required this.baseUrl, this.action = signinAction});

  /// The only action the sign-in and delete-challenge routes accept
  /// (`lead` and `support` tokens are refused there).
  static const signinAction = 'signin';

  static final _siteKeyShape = RegExp(r'^[0-9A-Za-z_-]{8,80}$');

  final String siteKey;

  /// Origin only (https, or http on localhost in debug builds).
  final Uri baseUrl;
  final String action;

  TurnstileConfig withAction(String value) =>
      value == action ? this : TurnstileConfig(siteKey: siteKey, baseUrl: baseUrl, action: value);

  /// Null when [siteKey] and [baseUrl] are both unset: this build has no
  /// Turnstile (then no human check is sent). One without the other, or a bad
  /// value, throws: a half configured check must not pass silently.
  static TurnstileConfig? fromDefines({bool isDebug = kDebugMode}) {
    return resolve(
      siteKey: const String.fromEnvironment('TURNSTILE_SITE_KEY'),
      baseUrl: const String.fromEnvironment('TURNSTILE_BASE_URL'),
      isDebug: isDebug,
    );
  }

  static TurnstileConfig? resolve({required String siteKey, required String baseUrl, required bool isDebug}) {
    final key = siteKey.trim();
    final base = baseUrl.trim();
    if (key.isEmpty && base.isEmpty) return null;
    if (key.isEmpty || base.isEmpty) {
      throw const InvalidTurnstileConfig('TURNSTILE_SITE_KEY and TURNSTILE_BASE_URL must be set together.');
    }
    // The key goes into generated HTML: only a plain token shape is allowed.
    if (!_siteKeyShape.hasMatch(key)) {
      throw const InvalidTurnstileConfig('TURNSTILE_SITE_KEY is not a Turnstile site key.');
    }
    final uri = Uri.tryParse(base);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const InvalidTurnstileConfig('TURNSTILE_BASE_URL is not an absolute URL.');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      throw const InvalidTurnstileConfig('TURNSTILE_BASE_URL must be an origin only, e.g. https://www.example.co.za');
    }
    final local = const {'localhost', '127.0.0.1', '10.0.2.2'}.contains(uri.host);
    final ok = uri.scheme == 'https' || (uri.scheme == 'http' && isDebug && local);
    if (!ok) {
      throw const InvalidTurnstileConfig('TURNSTILE_BASE_URL must use https (http only for localhost in debug builds).');
    }
    return TurnstileConfig(siteKey: key, baseUrl: uri.replace(path: ''));
  }

  @override
  String toString() => 'TurnstileConfig(baseUrl: $baseUrl, action: $action)'; // never the key in logs

  @override
  bool operator ==(Object other) =>
      other is TurnstileConfig && other.siteKey == siteKey && other.baseUrl == baseUrl && other.action == action;

  @override
  int get hashCode => Object.hash(siteKey, baseUrl, action);
}
