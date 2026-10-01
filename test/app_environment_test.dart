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

    test('a hostname that merely starts with a local host is not local', () {
      for (final url in ['http://localhost.evil.com', 'http://127.0.0.1.evil.com', 'http://10.0.2.2.evil.com']) {
        expect(
          () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: true),
          throwsA(isA<InvalidEnvironment>()),
          reason: url,
        );
      }
    });

    test('userinfo cannot smuggle a local host in front of another one', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'http://localhost@evil.com', isDebug: true),
        throwsA(isA<InvalidEnvironment>()),
      );
    });

    test('IPv6 loopback over http is refused (the Android debug config does not allow it)', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'http://[::1]:8000', isDebug: true),
        throwsA(isA<InvalidEnvironment>()),
      );
    });

    test('scheme and host are case-insensitive', () {
      expect(
        AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'HTTPS://API.Example.co.za', isDebug: false).apiBaseUrl.toString(),
        'https://api.example.co.za',
      );
      expect(
        AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: 'HTTP://LOCALHOST:8000', isDebug: true).apiBaseUrl.toString(),
        'http://localhost:8000',
      );
    });

    test('whitespace-padded defines are trimmed', () {
      final env = AppEnvironment.resolve(flavor: ' prod ', apiBaseUrl: '  https://api.example.co.za/ \n', isDebug: false);
      expect(env.flavor, AppFlavor.prod);
      expect(env.apiBaseUrl.toString(), 'https://api.example.co.za');
    });

    test('a whitespace-only API_BASE_URL counts as missing', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: '   ', isDebug: true),
        throwsA(isA<InvalidEnvironment>().having((e) => e.message, 'message', contains('needs --dart-define'))),
      );
    });

    test('error messages never echo the raw define (it may hold credentials)', () {
      for (final url in [
        'https://user:secretpw@api.example.co.za',
        'http://user:secretpw@api.example.co.za',
        'ftp://user:secretpw@api.example.co.za',
        'user:secretpw@api.example.co.za',
        'https://api.example.co.za/v1?token=secretpw',
        'https://api.example.co.za/#secretpw',
        'secretpw',
      ]) {
        expect(
          () => AppEnvironment.resolve(flavor: 'prod', apiBaseUrl: url, isDebug: true),
          throwsA(isA<InvalidEnvironment>().having((e) => e.toString(), 'toString', isNot(contains('secretpw')))),
          reason: url,
        );
      }
    });

    test('an unknown flavor is not echoed either', () {
      expect(
        () => AppEnvironment.resolve(flavor: 'secretpw', apiBaseUrl: '', isDebug: true),
        throwsA(isA<InvalidEnvironment>().having((e) => e.toString(), 'toString', isNot(contains('secretpw')))),
      );
    });
  });

  group('missing APP_FLAVOR', () {
    test('defaults to demo in debug, profile and test builds', () {
      for (final flavor in ['', '   ']) {
        expect(AppEnvironment.resolve(flavor: flavor, apiBaseUrl: '', isDebug: true).isDemo, isTrue);
        expect(AppEnvironment.resolve(flavor: flavor, apiBaseUrl: '', isDebug: false).isDemo, isTrue);
      }
    });

    test('is an error in a release build, so a forgotten define cannot ship the demo', () {
      for (final flavor in ['', '   ']) {
        expect(
          () => AppEnvironment.resolve(flavor: flavor, apiBaseUrl: '', isDebug: false, isRelease: true),
          throwsA(isA<InvalidEnvironment>().having((e) => e.message, 'message', contains('APP_FLAVOR'))),
        );
      }
    });

    test('an explicit demo flavor is fine in a release build', () {
      expect(AppEnvironment.resolve(flavor: 'demo', apiBaseUrl: '', isDebug: false, isRelease: true).isDemo, isTrue);
    });
  });
}
