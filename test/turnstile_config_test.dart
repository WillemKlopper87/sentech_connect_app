import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_html.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';

TurnstileConfig? _resolve(String key, String base, {bool debug = false}) =>
    TurnstileConfig.resolve(siteKey: key, baseUrl: base, isDebug: debug);

void main() {
  group('TurnstileConfig.resolve', () {
    test('nothing set means no Turnstile in this build (dev and test stacks)', () {
      expect(_resolve('', ''), isNull);
      expect(_resolve('  ', ' '), isNull);
      expect(TurnstileConfig.fromDefines(), isNull); // no --dart-define in tests
    });

    test('a valid pair resolves to the origin and the signin action', () {
      final config = _resolve('0x4AAAAAAAbcdEFGH-_12', 'https://www.example.co.za/')!;
      expect(config.baseUrl.toString(), 'https://www.example.co.za');
      expect(config.action, 'signin');
    });

    test('one without the other is refused (a half configured check must not pass)', () {
      expect(() => _resolve('0x4AAAAAAAbcdEFGH', ''), throwsA(isA<InvalidEnvironment>()));
      expect(() => _resolve('', 'https://www.example.co.za'), throwsA(isA<InvalidEnvironment>()));
    });

    test('a site key that could break out of the page is refused', () {
      const bad = ["abc'+alert(1)+'", 'short', 'has space 12345', '<script>12345', 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa'];
      for (final key in bad) {
        expect(() => _resolve(key, 'https://www.example.co.za'), throwsA(isA<InvalidTurnstileConfig>()), reason: key);
      }
    });

    test('the base URL must be an https origin; http only for localhost in debug builds', () {
      const key = '0x4AAAAAAAbcdEFGH';
      expect(() => _resolve(key, 'http://www.example.co.za'), throwsA(isA<InvalidTurnstileConfig>()));
      expect(() => _resolve(key, 'http://localhost:3000'), throwsA(isA<InvalidTurnstileConfig>()));
      expect(_resolve(key, 'http://localhost:3000', debug: true)!.baseUrl.host, 'localhost');
      const badUrls = ['https://u:p@www.example.co.za', 'https://www.example.co.za/path', 'https://www.example.co.za?x=1', 'not a url', 'www.example.co.za'];
      for (final bad in badUrls) {
        expect(() => _resolve(key, bad), throwsA(isA<InvalidTurnstileConfig>()), reason: bad);
      }
    });

    test('the error text never contains the raw values', () {
      try {
        _resolve('SECRET-KEY-VALUE-123', 'http://evil.example');
        fail('should throw');
      } on InvalidTurnstileConfig catch (e) {
        expect(e.toString(), isNot(contains('SECRET-KEY-VALUE-123')));
        expect(e.toString(), isNot(contains('evil.example')));
      }
    });

    test('toString does not print the site key', () {
      expect(_resolve('0x4AAAAAAAbcdEFGH', 'https://www.example.co.za').toString(), isNot(contains('0x4AAAAAAAbcdEFGH')));
    });
  });

  group('the widget page', () {
    final config = _resolve('0x4AAAAAAAbcdEFGH', 'https://www.example.co.za')!;
    final html = buildTurnstileHtml(config);

    test('renders the signin widget with the site key, loads only Cloudflare, posts to the channel', () {
      expect(html, contains("sitekey: '0x4AAAAAAAbcdEFGH'"));
      expect(html, contains("action: 'signin'"));
      expect(html, contains('https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit'));
      expect(html, contains('$turnstileChannelName.postMessage'));
      expect(html, contains("retry: 'never'"));
      expect(html, contains("'refresh-expired': 'never'"));
      expect(RegExp(r'src="https?://').allMatches(html).length, 1, reason: 'one external script only');
    });

    test('has a viewport (the widget is mobile sized) and a reset hook', () {
      expect(html, contains('name="viewport"'));
      expect(html, contains('function resetTurnstile'));
    });
  });

  group('TurnstileMessage.parse', () {
    test('understands the page messages', () {
      expect(TurnstileMessage.parse('{"t":"ready","v":""}'), isA<TurnstileReady>());
      expect(TurnstileMessage.parse('{"t":"interactive","v":""}'), isA<TurnstileInteractive>());
      expect(TurnstileMessage.parse('{"t":"expired","v":""}'), isA<TurnstileExpired>());
      expect(TurnstileMessage.parse('{"t":"timeout","v":""}'), isA<TurnstileWidgetTimeout>());
      expect((TurnstileMessage.parse('{"t":"token","v":"abc.def"}')! as TurnstileTokenMessage).token, 'abc.def');
      expect((TurnstileMessage.parse('{"t":"error","v":"110100"}')! as TurnstileWidgetError).code, '110100');
    });

    test('drops anything unexpected', () {
      final tooLong = 'a' * 2049;
      final bads = ['', 'not json', '[]', '{"t":"token"}', '{"t":"token","v":""}', '{"t":"token","v":5}', '{"t":"evil","v":"x"}', '{"v":"x"}', '{"t":"token","v":"$tooLong"}', 'x' * 5000];
      for (final bad in bads) {
        expect(TurnstileMessage.parse(bad), isNull, reason: bad.length > 60 ? 'long' : bad);
      }
    });

    test('a widget error keeps only a short code (never page text)', () {
      expect((TurnstileMessage.parse('{"t":"error","v":"<b>boom</b> with text"}')! as TurnstileWidgetError).code, 'unknown');
    });

    test('a token message never prints its token', () {
      expect(TurnstileMessage.parse('{"t":"token","v":"SECRETVALUE"}').toString(), isNot(contains('SECRETVALUE')));
    });
  });
}
