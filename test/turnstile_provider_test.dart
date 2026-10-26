import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sentech_connect_app/core/error/failure.dart';
import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_check_controller.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_provider.dart';

import 'helpers/fake_turnstile_surface.dart';

final _config = TurnstileConfig.resolve(siteKey: '0x4AAAAAAAbcdEFGH', baseUrl: 'https://www.example.co.za', isDebug: false)!;

const _ms = Duration(milliseconds: 40);

TurnstileCheckController _controller(FakeTurnstileSurface surface, {int retries = 2, Duration load = const Duration(seconds: 5), Duration challenge = const Duration(seconds: 5)}) =>
    TurnstileCheckController(surface: surface, config: _config, loadTimeout: load, challengeTimeout: challenge, maxAutoRetries: retries);

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('TurnstileCheckController', () {
    test('loads the page, then delivers the token once and releases the surface', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface);
      await check.start();
      expect(surface.loads, 1);
      expect(check.value.phase, TurnstilePhase.loading);
      surface
        ..send(const TurnstileReady())
        ..send(const TurnstileInteractive());
      expect(check.value.phase, TurnstilePhase.challenge);
      surface.sendRaw('{"t":"token","v":"$testTurnstileToken"}');
      final result = await check.result;
      expect((result as TurnstileSolved).token, testTurnstileToken);
      expect(check.value.phase, TurnstilePhase.solved);
      await _pump();
      expect(surface.disposed, isTrue);
      check.dispose();
    });

    test('a second token from the page is ignored (single use)', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface);
      await check.start();
      surface.sendRaw('{"t":"token","v":"first-token"}');
      // The channel is closed after delivery; even a late or replayed message cannot change the result.
      surface.sendRaw('{"t":"token","v":"second-token"}');
      expect((await check.result as TurnstileSolved).token, 'first-token');
      check.cancel(); // after delivery: nothing happens
      expect((await check.result as TurnstileSolved).token, 'first-token');
      check.dispose();
    });

    test('a widget error resets quietly up to the budget, then asks the customer', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface, retries: 2);
      await check.start();
      surface.send(const TurnstileWidgetError('110100'));
      await _pump();
      expect(surface.resets, 1);
      expect(check.value.phase, TurnstilePhase.loading);
      surface.send(const TurnstileWidgetError('110100'));
      await _pump();
      expect(surface.resets, 2);
      surface.send(const TurnstileWidgetError('110100'));
      expect(check.value, const TurnstileCheckState(TurnstilePhase.failed, TurnstileFailure.widget));
      expect(surface.resets, 2, reason: 'no more quiet retries');
      check.dispose();
    });

    test('Retry after a failure starts a fresh challenge and a fresh retry budget', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface, retries: 0);
      await check.start();
      surface.send(const TurnstileWidgetError('1'));
      expect(check.value.phase, TurnstilePhase.failed);
      await check.retry();
      expect(surface.resets, 1);
      expect(check.value.phase, TurnstilePhase.loading);
      surface
        ..send(const TurnstileReady())
        ..sendRaw('{"t":"token","v":"fresh"}');
      expect((await check.result as TurnstileSolved).token, 'fresh');
      check.dispose();
    });

    test('an expired token or a widget timeout before the token is used resets quietly, then fails as timeout', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface, retries: 1);
      await check.start();
      surface.send(const TurnstileExpired());
      await _pump();
      expect(surface.resets, 1);
      surface.send(const TurnstileWidgetTimeout());
      expect(check.value, const TurnstileCheckState(TurnstilePhase.failed, TurnstileFailure.timeout));
      check.dispose();
    });

    test('a page that never answers fails as network after the load timeout', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface, load: _ms);
      await check.start();
      await Future<void>.delayed(_ms * 3);
      expect(check.value, const TurnstileCheckState(TurnstilePhase.failed, TurnstileFailure.network));
      check.dispose();
    });

    test('a widget that rendered but never finishes fails as timeout after the challenge timeout', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface, challenge: _ms);
      await check.start();
      surface.send(const TurnstileReady());
      await Future<void>.delayed(_ms * 3);
      expect(check.value, const TurnstileCheckState(TurnstilePhase.failed, TurnstileFailure.timeout));
      check.dispose();
    });

    test('no network: the WebView page error fails as network at once (no quiet retry)', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface);
      await check.start();
      surface.send(const TurnstilePageError());
      expect(check.value, const TurnstileCheckState(TurnstilePhase.failed, TurnstileFailure.network));
      expect(surface.resets, 0);
      check.dispose();
    });

    test('a token that arrives after the attempt failed is void', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface);
      await check.start();
      surface.send(const TurnstilePageError());
      surface.sendRaw('{"t":"token","v":"late"}');
      expect(check.isFinished, isFalse);
      expect(check.value.phase, TurnstilePhase.failed);
      check.dispose();
    });

    test('a load that throws fails as widget', () async {
      final surface = FakeTurnstileSurface()..loadError = StateError('webview gone');
      final check = _controller(surface);
      await check.start();
      expect(check.value, const TurnstileCheckState(TurnstilePhase.failed, TurnstileFailure.widget));
      check.dispose();
    });

    test('cancel ends the check, drops the surface, and later messages change nothing', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface);
      await check.start();
      check.cancel();
      expect(await check.result, isA<TurnstileCancelled>());
      surface.sendRaw('{"t":"token","v":"after-cancel"}');
      expect(await check.result, isA<TurnstileCancelled>());
      await _pump();
      expect(surface.disposed, isTrue);
      check.dispose();
    });

    test('nothing the controller prints contains the token', () async {
      final surface = FakeTurnstileSurface();
      final check = _controller(surface);
      await check.start();
      surface.sendRaw('{"t":"token","v":"$testTurnstileToken"}');
      final result = await check.result;
      for (final text in [result.toString(), check.value.toString(), check.toString()]) {
        expect(text, isNot(contains('SECRETTOKEN')));
      }
      check.dispose();
    });
  });

  group('TurnstileWebViewProvider', () {
    late List<FakeTurnstileSurface> surfaces;
    late _Presenter presenter;
    late TurnstileWebViewProvider provider;

    setUp(() {
      surfaces = [];
      presenter = _Presenter();
      provider = TurnstileWebViewProvider(
        config: _config,
        presenter: presenter,
        surfaceFactory: () {
          final surface = FakeTurnstileSurface();
          surfaces.add(surface);
          return surface;
        },
        loadTimeout: const Duration(seconds: 5),
        challengeTimeout: const Duration(seconds: 5),
      );
    });

    test('returns the token the widget produced', () async {
      presenter.onPresent = (check) => surfaces.single.sendRaw('{"t":"token","v":"tok-1"}');
      expect(await provider.token(), 'tok-1');
      expect(presenter.shown, 1);
    });

    test('every call runs a NEW check with a new surface: a token is never reused', () async {
      var n = 0;
      presenter.onPresent = (check) => surfaces.last.sendRaw('{"t":"token","v":"tok-${++n}"}');
      expect(await provider.token(), 'tok-1');
      expect(await provider.token(), 'tok-2');
      expect(surfaces, hasLength(2));
      expect(surfaces.every((s) => s.disposed), isTrue);
    });

    test('concurrent calls queue: one visible check at a time, two tokens', () async {
      var n = 0;
      presenter.onPresent = (check) => surfaces.last.sendRaw('{"t":"token","v":"tok-${++n}"}');
      final both = await Future.wait([provider.token(), provider.token()]);
      expect(both.toSet(), {'tok-1', 'tok-2'});
      expect(presenter.maxConcurrent, 1);
    });

    test('the customer cancels in the sheet: HumanCheckCancelled', () async {
      presenter.onPresent = (check) => check.cancel();
      await expectLater(provider.token(), throwsA(isA<HumanCheckCancelled>()));
    });

    test('the customer dismisses the sheet (back button, swipe): the check is cancelled, not left running', () async {
      presenter.closeWithoutResult = true;
      await expectLater(provider.token(), throwsA(isA<HumanCheckCancelled>()));
      expect(surfaces.single.disposed, isTrue);
    });

    test('nowhere to show the check: HumanCheckUnavailable', () async {
      presenter.error = const HumanCheckUnavailable();
      await expectLater(provider.token(), throwsA(isA<HumanCheckUnavailable>()));
    });

    test('a presenter or surface bug becomes HumanCheckUnavailable without its message', () async {
      presenter.error = StateError('page said: $testTurnstileToken');
      try {
        await provider.token();
        fail('should throw');
      } on HumanCheckUnavailable catch (e) {
        expect(e.toString(), isNot(contains('SECRETTOKEN')));
      }
    });

    test('a failed widget can be retried inside the same sheet and then succeeds', () async {
      presenter.onPresent = (check) async {
        final surface = surfaces.single;
        await _pump();
        surface.send(const TurnstilePageError());
        await check.retry();
        surface.sendRaw('{"t":"token","v":"after-retry"}');
      };
      expect(await provider.token(), 'after-retry');
    });

    test('repositories see typed failures, never a throw', () async {
      presenter.onPresent = (check) => check.cancel();
      expect((await acquireHumanCheck(provider)).getLeft().toNullable(), isA<HumanCheckCancelledFailure>());
      presenter
        ..onPresent = null
        ..error = const HumanCheckUnavailable();
      expect((await acquireHumanCheck(provider)).getLeft().toNullable(), isA<HumanVerificationUnavailableFailure>());
    });
  });
}

/// Records what the provider asked it to show and lets a test act as the
/// customer / the page.
class _Presenter implements HumanCheckPresenter {
  FutureOr<void> Function(TurnstileCheckController check)? onPresent;
  Object? error;
  bool closeWithoutResult = false;
  var shown = 0;
  var _open = 0;
  var maxConcurrent = 0;

  @override
  Future<void> present(TurnstileCheckController check) async {
    if (error != null) throw error!;
    shown++;
    _open++;
    if (_open > maxConcurrent) maxConcurrent = _open;
    try {
      await _pump(); // the sheet takes a frame to open; the page loads meanwhile
      if (closeWithoutResult) return;
      await onPresent?.call(check);
      await check.result; // the sheet closes itself once the check is done
    } finally {
      _open--;
    }
  }
}
