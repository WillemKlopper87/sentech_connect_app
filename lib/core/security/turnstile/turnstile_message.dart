import 'dart:convert';

/// What the widget page tells the app through the JavaScript channel.
sealed class TurnstileMessage {
  const TurnstileMessage();

  /// Strict parse of one channel message; anything unexpected is dropped (null)
  /// so a page that was tampered with cannot inject state.
  static TurnstileMessage? parse(String raw) {
    if (raw.length > maxMessageLength) return null;
    final Object? decoded;
    try {
      decoded = jsonDecode(raw);
    } on FormatException {
      return null;
    }
    if (decoded is! Map) return null;
    final type = decoded['t'];
    final value = decoded['v'];
    switch (type) {
      case 'ready':
        return const TurnstileReady();
      case 'interactive':
        return const TurnstileInteractive();
      case 'token':
        if (value is String && value.isNotEmpty && value.length <= maxTokenLength) {
          return TurnstileTokenMessage(value);
        }
        return null;
      case 'error':
        // Cloudflare error codes are short alphanumerics; keep nothing else.
        final code = value is String && RegExp(r'^[0-9A-Za-z-]{1,16}$').hasMatch(value) ? value : 'unknown';
        return TurnstileWidgetError(code);
      case 'expired':
        return const TurnstileExpired();
      case 'timeout':
        return const TurnstileWidgetTimeout();
    }
    return null;
  }

  /// Turnstile tokens are at most 2048 characters.
  static const maxTokenLength = 2048;
  static const maxMessageLength = 4096;
}

/// The widget finished rendering (the script loaded and the widget exists).
class TurnstileReady extends TurnstileMessage {
  const TurnstileReady();
}

/// The widget needs the customer to do something (a tick or a puzzle).
class TurnstileInteractive extends TurnstileMessage {
  const TurnstileInteractive();
}

/// A fresh token. Its [toString] never shows it.
class TurnstileTokenMessage extends TurnstileMessage {
  const TurnstileTokenMessage(this.token);

  final String token;

  @override
  String toString() => 'TurnstileTokenMessage(<redacted>)';
}

class TurnstileWidgetError extends TurnstileMessage {
  const TurnstileWidgetError(this.code);

  final String code;

  @override
  String toString() => 'TurnstileWidgetError($code)';
}

/// The challenge was solved but the token expired before it was used.
class TurnstileExpired extends TurnstileMessage {
  const TurnstileExpired();
}

/// The interactive challenge timed out.
class TurnstileWidgetTimeout extends TurnstileMessage {
  const TurnstileWidgetTimeout();
}

/// The page itself could not load (no network, DNS, TLS), reported by the
/// WebView, not by the widget.
class TurnstilePageError extends TurnstileMessage {
  const TurnstilePageError();
}
