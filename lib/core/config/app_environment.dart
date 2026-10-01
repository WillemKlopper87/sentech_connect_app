import 'package:flutter/foundation.dart';

/// `demo` runs entirely on mock repositories (no network, works offline);
/// `prod` talks to the platform API at [AppEnvironment.apiBaseUrl].
enum AppFlavor { demo, prod }

class InvalidEnvironment implements Exception {
  const InvalidEnvironment(this.message);

  final String message;

  @override
  String toString() => 'InvalidEnvironment: $message';
}

/// Build-time configuration from `--dart-define=APP_FLAVOR=demo|prod` and
/// `--dart-define=API_BASE_URL=https://...`. Invalid combinations fail at
/// startup instead of silently falling back.
class AppEnvironment {
  const AppEnvironment({required this.flavor, this.apiBaseUrl});

  static const demo = AppEnvironment(flavor: AppFlavor.demo);

  /// Hosts that this app accepts over cleartext HTTP, in debug builds only.
  /// This is the Dart-side allowlist; the Android debug network security
  /// config (android/app/src/debug/res/xml/network_security_config.xml) must
  /// permit the same hosts (`localhost`, `127.0.0.1` and `10.0.2.2`), and the
  /// release config allows no cleartext at all.
  static const localDevHosts = {'localhost', '127.0.0.1', '10.0.2.2'};

  final AppFlavor flavor;

  /// Origin of the API (no path); requests use `/v1/...` paths.
  final Uri? apiBaseUrl;

  bool get isDemo => flavor == AppFlavor.demo;

  factory AppEnvironment.fromDefines() => AppEnvironment.resolve(
        flavor: const String.fromEnvironment('APP_FLAVOR'),
        apiBaseUrl: const String.fromEnvironment('API_BASE_URL'),
        isDebug: kDebugMode,
        isRelease: kReleaseMode,
      );

  /// A missing (or blank) `APP_FLAVOR` means `demo` in debug, profile and
  /// test builds, but is an error when [isRelease]: a forgotten define must
  /// not silently ship a demo build with mock data.
  ///
  /// Error messages never include the raw defines, which can hold credentials.
  factory AppEnvironment.resolve({
    required String flavor,
    required String apiBaseUrl,
    required bool isDebug,
    bool isRelease = false,
  }) {
    final name = flavor.trim();
    if (name.isEmpty) {
      if (isRelease) {
        throw const InvalidEnvironment(
          'Release builds must set --dart-define=APP_FLAVOR=demo or --dart-define=APP_FLAVOR=prod.',
        );
      }
      return demo;
    }
    switch (name) {
      case 'demo':
        return demo;
      case 'prod':
        return AppEnvironment(flavor: AppFlavor.prod, apiBaseUrl: _checkedBaseUrl(apiBaseUrl, isDebug: isDebug));
      default:
        throw const InvalidEnvironment('APP_FLAVOR must be "demo" or "prod".');
    }
  }

  static Uri _checkedBaseUrl(String raw, {required bool isDebug}) {
    if (raw.trim().isEmpty) {
      throw const InvalidEnvironment('APP_FLAVOR=prod needs --dart-define=API_BASE_URL=https://...');
    }
    final uri = Uri.tryParse(raw.trim());
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const InvalidEnvironment('API_BASE_URL is not an absolute http(s) URL.');
    }
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment || (uri.path.isNotEmpty && uri.path != '/')) {
      throw const InvalidEnvironment('API_BASE_URL must be an origin only, e.g. https://api.example.co.za');
    }
    final origin = uri.replace(path: '');
    if (uri.scheme == 'https') return origin;
    if (uri.scheme == 'http' && isDebug && localDevHosts.contains(uri.host)) return origin;
    throw const InvalidEnvironment(
      'API_BASE_URL must use https (http is allowed only for localhost, 127.0.0.1 or 10.0.2.2 in debug builds).',
    );
  }
}
