import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';

void main() {
  group('AppEnvironment.resolve', () {
    test('defaults to demo with no API base URL', () {
      final env = AppEnvironment.resolve(flavor: 'demo', apiBaseUrl: '', isDebug: false);
      expect(env.isDemo, isTrue);
      expect(env.apiBaseUrl, isNull);
    });

    test('prod requires API_BASE_URL', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: '', isDebug: true),
        throwsA(isA<InvalidEnvironment>()),
      );
    });

    test('prod accepts https and strips a trailing slash', () {
      final env = AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'https://api.example.co.za/', isDebug: false);
      expect(env.isDemo, isFalse);
      expect(env.apiBaseUrl.toString(), 'https://api.example.co.za');
    });

    test('cleartext http is refused for non-local hosts, even in debug', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'http://api.example.co.za', isDebug: true),
        throwsA(isA<InvalidEnvironment>()),
      );
    });

    test('cleartext http to the emulator host or localhost is allowed only in debug builds', () {
      for (final url in ['http://10.0.2.2:8088', 'http://127.0.0.1:8088', 'http://localhost:8000']) {
        expect(AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: true).apiBaseUrl.toString(), url);
        expect(
          () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: false),
          throwsA(isA<InvalidEnvironment>()),
        );
      }
    });

    test('rejects unknown flavors, paths, query strings, credentials and odd schemes', () {
      expect(() => AppEnvironment.resolve(flavor: 'qa', apiBaseUrl: '', isDebug: true), throwsA(isA<InvalidEnvironment>()));
      for (final url in [
        'https://api.example.co.za/v1',
        'https://api.example.co.za?x=1',
        'https://user:pw@api.example.co.za',
        'ftp://api.example.co.za',
        'api.example.co.za',
      ]) {
        expect(
          () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: true),
          throwsA(isA<InvalidEnvironment>()),
          reason: url,
        );
      }
    });
  });
}
