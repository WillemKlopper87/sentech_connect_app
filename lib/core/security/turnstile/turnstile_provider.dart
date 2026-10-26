import 'dart:async';

import 'package:sentech_connect_app/core/security/human_check_provider.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_check_controller.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_surface.dart';
import 'package:sentech_connect_app/core/security/turnstile/webview_turnstile_surface.dart';

/// Shows a running check to the customer. Returns when the customer can no
/// longer see it: after the check finished (token or cancel), or because they
/// closed it (then the presenter calls [TurnstileCheckController.cancel]).
/// Throws [HumanCheckUnavailable] when there is nowhere to show it.
abstract interface class HumanCheckPresenter {
  Future<void> present(TurnstileCheckController check);
}

/// Tier B human check: Cloudflare Turnstile in a WebView, action `signin`.
///
/// Every [token] call runs a NEW check (new page, new widget) and hands the
/// token over once. Concurrent calls queue up behind each other; they never
/// share a token.
class TurnstileWebViewProvider implements HumanCheckProvider {
  TurnstileWebViewProvider({
    required this.config,
    required this.presenter,
    TurnstileSurface Function()? surfaceFactory,
    this.loadTimeout = const Duration(seconds: 25),
    this.challengeTimeout = const Duration(seconds: 120),
    this.maxAutoRetries = 2,
  }) : _surfaceFactory = surfaceFactory ?? WebViewTurnstileSurface.new;

  final TurnstileConfig config;
  final HumanCheckPresenter presenter;
  final Duration loadTimeout;
  final Duration challengeTimeout;
  final int maxAutoRetries;
  final TurnstileSurface Function() _surfaceFactory;

  Future<void> _queue = Future<void>.value();

  @override
  Future<String?> token() {
    final run = _queue.then((_) => _runOne());
    _queue = run.then<void>((_) {}, onError: (Object _) {});
    return run;
  }

  Future<String?> _runOne() async {
    final check = TurnstileCheckController(
      surface: _surfaceFactory(),
      config: config,
      loadTimeout: loadTimeout,
      challengeTimeout: challengeTimeout,
      maxAutoRetries: maxAutoRetries,
    );
    try {
      final shown = presenter.present(check);
      unawaited(check.start());
      // Whichever comes first: the check ends, or the customer closes the view.
      final first = await Future.any<Object?>([check.result, shown.then<Object?>((_) => null)]);
      if (first == null) {
        check.cancel(); // closed without a result
      }
      final result = await check.result;
      await shown.catchError((Object _) {});
      switch (result) {
        case TurnstileSolved(:final token):
          return token;
        case TurnstileCancelled():
          throw const HumanCheckCancelled();
      }
    } on HumanCheckCancelled {
      rethrow;
    } on HumanCheckUnavailable {
      rethrow;
    } on Object {
      throw const HumanCheckUnavailable(); // never carries the cause: it could echo page data
    } finally {
      check.dispose();
    }
  }
}
