import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_html.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_surface.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Runs the Turnstile widget in a `webview_flutter` WebView.
///
/// The page is an HTML string loaded with the platform's public web origin as
/// base URL (see [TurnstileConfig]). JavaScript is on (the widget needs it),
/// the user agent is left alone (Cloudflare asks for a stable one), the only
/// bridge is the one-way [turnstileChannelName] channel, and the main frame
/// may only be the widget page itself or Cloudflare's challenge host.
class WebViewTurnstileSurface implements TurnstileSurface {
  WebViewTurnstileSurface({WebViewController? controller}) : _controller = controller ?? WebViewController();

  final WebViewController _controller;
  final _messages = StreamController<TurnstileMessage>.broadcast();
  var _configured = false;
  var _ready = false;
  var _disposed = false;

  @override
  Stream<TurnstileMessage> get messages => _messages.stream;

  void _emit(TurnstileMessage message) {
    if (!_disposed && !_messages.isClosed) _messages.add(message);
  }

  Future<void> _configure(TurnstileConfig config) async {
    if (_configured) return;
    _configured = true;
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setBackgroundColor(const Color(0x00000000));
    await _controller.addJavaScriptChannel(
      turnstileChannelName,
      onMessageReceived: (message) {
        final parsed = TurnstileMessage.parse(message.message);
        if (parsed == null) return;
        if (parsed is TurnstileReady) _ready = true;
        _emit(parsed);
      },
    );
    await _controller.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          return isAllowedTurnstileNavigation(request.url, config) ? NavigationDecision.navigate : NavigationDecision.prevent;
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame ?? true) _emit(const TurnstilePageError());
        },
      ),
    );
  }

  @override
  Future<void> load(TurnstileConfig config) async {
    await _configure(config);
    _ready = false;
    await _controller.loadHtmlString(buildTurnstileHtml(config), baseUrl: config.baseUrl.toString());
  }

  @override
  Future<void> reset(TurnstileConfig config) async {
    if (_ready) {
      await _controller.runJavaScript('resetTurnstile()');
    } else {
      await load(config);
    }
  }

  @override
  Widget buildView(BuildContext context) => WebViewWidget(controller: _controller);

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _messages.close();
  }
}

/// The WebView may show the widget page itself (`about:`, `data:` documents
/// and the registered base origin) and Cloudflare's challenge frames, and
/// nothing else: no redirect to another site, no `javascript:`, `file:` or
/// custom scheme.
bool isAllowedTurnstileNavigation(String url, TurnstileConfig config) {
  final uri = Uri.tryParse(url);
  if (uri == null) return false;
  if (uri.scheme == 'about' || uri.scheme == 'data') return true;
  if (uri.scheme == 'https') {
    return uri.host == turnstileScriptHost || uri.host == config.baseUrl.host;
  }
  // The registered origin itself (http only ever exists for localhost in debug).
  return uri.scheme == config.baseUrl.scheme && uri.host == config.baseUrl.host;
}
