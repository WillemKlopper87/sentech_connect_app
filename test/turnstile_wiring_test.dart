import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/app/locator.dart';
import 'package:sentech_connect_app/core/config/app_environment.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/human_check_config.dart';
import 'package:sentech_connect_app/core/security/human_check_gate.dart';
import 'package:sentech_connect_app/core/security/turnstile/webview_turnstile_surface.dart';
import 'package:sentech_connect_app/shared/widgets/human_check_sheet.dart';

import 'helpers/test_setup.dart';

final _prod = AppEnvironment(flavor: AppFlavor.prod, apiBaseUrl: Uri.parse('https://api.example.co.za'));
final _config = TurnstileConfig.resolve(siteKey: '0x4AAAAAAAbcdEFGH', baseUrl: 'https://www.example.co.za', isDebug: false)!;

void main() {
  group('provider selection by flavor and config', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      await locator.reset();
    });

    test('demo flavor: mock-only, no WebView provider, no presenter, no HumanCheckProvider at all', () {
      setupLocator(turnstile: _config); // even with a config handed in
      registerTestFakes();
      expect(locator.isRegistered<HumanCheckProvider>(), isFalse);
      expect(locator.isRegistered<NavigatorHumanCheckPresenter>(), isFalse);
    });

    test('prod without Turnstile defines (dev and test stacks): the gate has no fallback config', () {
      setupLocator(environment: _prod);
      registerTestFakes();
      expect(locator<HumanCheckGate>().buildConfig, isNull);
      expect(locator<HumanCheckConfigRepository>(), isA<HttpHumanCheckConfigRepository>());
      expect(locator.isRegistered<HumanCheckProvider>(), isFalse, reason: 'each repository gets its own action provider');
    });

    test('prod with Turnstile defines: they are the fallback of the gate, presented over the router navigator', () {
      setupLocator(environment: _prod, turnstile: _config);
      registerTestFakes();
      expect(locator<HumanCheckGate>().buildConfig, _config);
      expect(locator<NavigatorHumanCheckPresenter>().navigatorKey, isA<GlobalKey<NavigatorState>>());
    });
  });

  group('WebView navigation allow-list', () {
    test('the widget page and Cloudflare only', () {
      for (final ok in ['about:blank', 'about:srcdoc', 'data:text/html,hi', 'https://www.example.co.za/', 'https://challenges.cloudflare.com/cdn-cgi/challenge-platform/h/b/x']) {
        expect(isAllowedTurnstileNavigation(ok, _config), isTrue, reason: ok);
      }
      for (final bad in ['https://evil.example/', 'http://challenges.cloudflare.com/', 'http://www.example.co.za/', 'javascript:alert(1)', 'file:///etc/passwd', 'intent://x#Intent;end', 'sentech://x', 'https://challenges.cloudflare.com.evil.example/', '', ':::']) {
        expect(isAllowedTurnstileNavigation(bad, _config), isFalse, reason: bad);
      }
    });
  });
}
