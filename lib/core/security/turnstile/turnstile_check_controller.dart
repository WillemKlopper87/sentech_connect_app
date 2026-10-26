import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_surface.dart';

enum TurnstilePhase {
  /// The page or widget is loading.
  loading,

  /// The widget wants the customer to tick or solve something.
  challenge,

  /// A token was delivered. Terminal.
  solved,

  /// It did not work; the customer can retry or cancel. See [TurnstileFailure].
  failed,

  /// The customer backed out. Terminal.
  cancelled,
}

enum TurnstileFailure { network, widget, timeout }

/// The visible state. Never holds the token.
@immutable
class TurnstileCheckState {
  const TurnstileCheckState(this.phase, [this.failure]);

  final TurnstilePhase phase;
  final TurnstileFailure? failure;

  @override
  bool operator ==(Object other) => other is TurnstileCheckState && other.phase == phase && other.failure == failure;

  @override
  int get hashCode => Object.hash(phase, failure);

  @override
  String toString() => 'TurnstileCheckState($phase${failure == null ? '' : ', $failure'})';
}

/// How one check ended.
sealed class TurnstileResult {
  const TurnstileResult();
}

/// The one-shot token. [toString] never shows it.
class TurnstileSolved extends TurnstileResult {
  const TurnstileSolved(this.token);

  final String token;

  @override
  String toString() => 'TurnstileSolved(<redacted>)';
}

class TurnstileCancelled extends TurnstileResult {
  const TurnstileCancelled();
}

/// Runs ONE human check: loads the widget, follows its messages, retries
/// quietly a bounded number of times, and ends with a token or a cancel.
///
/// Rules: the token is delivered exactly once and then forgotten (a second
/// token from the page is ignored); nothing here logs or exposes it besides
/// [result]; the customer can always [cancel] and, once it failed, [retry].
class TurnstileCheckController extends ValueNotifier<TurnstileCheckState> {
  TurnstileCheckController({
    required this._surface,
    required this._config,
    this.loadTimeout = const Duration(seconds: 25),
    this.challengeTimeout = const Duration(seconds: 120),
    this.maxAutoRetries = 2,
  }) : super(const TurnstileCheckState(TurnstilePhase.loading));

  final TurnstileSurface _surface;
  final TurnstileConfig _config;

  /// How long the page may take to render the widget (no network shows up
  /// here when the WebView does not report an error itself).
  final Duration loadTimeout;

  /// How long one attempt may take in total, including a puzzle.
  final Duration challengeTimeout;

  /// Quiet resets after a widget error, an expiry or a widget timeout, before
  /// the customer is shown the Retry button.
  final int maxAutoRetries;

  final _done = Completer<TurnstileResult>();
  StreamSubscription<TurnstileMessage>? _sub;
  Timer? _timer;
  var _autoRetries = 0;
  var _started = false;
  var _ready = false;
  var _disposed = false;

  /// Completes once, with the token or a cancel. A failure does not complete
  /// it: the customer decides between [retry] and [cancel].
  Future<TurnstileResult> get result => _done.future;

  bool get isFinished => _done.isCompleted;

  /// The widget view for the sheet (the surface is owned by this controller).
  Widget buildView(BuildContext context) => _surface.buildView(context);

  Future<void> start() async {
    if (_started || isFinished) return;
    _started = true;
    _sub = _surface.messages.listen(_onMessage, onError: (Object _) => _fail(TurnstileFailure.widget));
    _beginAttempt();
    try {
      await _surface.load(_config);
    } on Object {
      _fail(TurnstileFailure.widget);
    }
  }

  /// "Try again" after a failure: a fresh challenge, the automatic retry
  /// budget starts over.
  Future<void> retry() async {
    if (isFinished || value.phase != TurnstilePhase.failed) return;
    _autoRetries = 0;
    _beginAttempt();
    await _resetSurface();
  }

  /// Backs out. Safe at any time; after a token was delivered it does nothing.
  void cancel() {
    if (isFinished) return;
    _finish(const TurnstileCancelled(), TurnstilePhase.cancelled);
  }

  void _beginAttempt() {
    _ready = false;
    _set(const TurnstileCheckState(TurnstilePhase.loading));
    _arm(loadTimeout);
  }

  Future<void> _resetSurface() async {
    try {
      await _surface.reset(_config);
    } on Object {
      _fail(TurnstileFailure.widget);
    }
  }

  void _onMessage(TurnstileMessage message) {
    if (isFinished) return; // single use: nothing after the token or a cancel
    switch (message) {
      case TurnstileReady():
        _ready = true;
        _arm(challengeTimeout);
      case TurnstileInteractive():
        if (value.phase == TurnstilePhase.loading) _set(const TurnstileCheckState(TurnstilePhase.challenge));
      case TurnstileTokenMessage(:final token):
        if (value.phase == TurnstilePhase.failed) return; // a late token of a failed attempt is void
        _finish(TurnstileSolved(token), TurnstilePhase.solved);
      case TurnstilePageError():
        _fail(TurnstileFailure.network);
      case TurnstileWidgetError():
        _autoRetryOr(TurnstileFailure.widget);
      case TurnstileExpired():
        _autoRetryOr(TurnstileFailure.timeout);
      case TurnstileWidgetTimeout():
        _autoRetryOr(TurnstileFailure.timeout);
    }
  }

  void _autoRetryOr(TurnstileFailure failure) {
    if (value.phase == TurnstilePhase.failed) return;
    if (_autoRetries < maxAutoRetries) {
      _autoRetries++;
      _beginAttempt();
      unawaited(_resetSurface());
    } else {
      _fail(failure);
    }
  }

  void _arm(Duration after) {
    _timer?.cancel();
    _timer = Timer(after, () => _fail(_ready ? TurnstileFailure.timeout : TurnstileFailure.network));
  }

  void _fail(TurnstileFailure failure) {
    if (isFinished) return;
    _timer?.cancel();
    _set(TurnstileCheckState(TurnstilePhase.failed, failure));
  }

  void _finish(TurnstileResult result, TurnstilePhase phase) {
    _timer?.cancel();
    _set(TurnstileCheckState(phase));
    if (!_done.isCompleted) _done.complete(result);
    unawaited(_release());
  }

  Future<void> _release() async {
    await _sub?.cancel();
    _sub = null;
    try {
      await _surface.dispose();
    } on Object {
      // Clean-up is best effort.
    }
  }

  void _set(TurnstileCheckState next) {
    if (_disposed) return;
    value = next;
  }

  @override
  void dispose() {
    if (_disposed) return;
    if (!isFinished) cancel();
    _timer?.cancel();
    _disposed = true;
    super.dispose();
  }
}
