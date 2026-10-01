import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Hosts the gateway's payment page (ruling R-M4-3). Pops `true` when the
/// gateway sends the customer back to a return URL, `false` when closed.
/// Either way the caller polls the order: only the server-to-server
/// notification marks it paid. No JavaScript channels are exposed to the
/// page and no token or cookie of ours is ever injected; main-frame
/// navigation is pinned to the gateway host; cache, local storage and cookies
/// are cleared on close.
class PaymentWebViewPage extends StatefulWidget {
  const PaymentWebViewPage({super.key, required this.handoff});

  final PaymentHandoff handoff;

  @override
  State<PaymentWebViewPage> createState() => _PaymentWebViewPageState();
}

class _PaymentWebViewPageState extends State<PaymentWebViewPage> {
  late final WebViewController _controller;
  var _progress = 0;
  var _closed = false;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted) // gateway pages need JS
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (p) {
            if (mounted) setState(() => _progress = p);
          },
          onNavigationRequest: _onNavigation,
        ),
      );
    final handoff = widget.handoff;
    if (!isAllowedPaymentUrl(handoff.url, allowLocalHttp: kDebugMode)) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _close(false));
      return;
    }
    if (handoff.method == PaymentHandoffMethod.post) {
      _controller.loadRequest(
        handoff.url,
        method: LoadRequestMethod.post,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: Uint8List.fromList(utf8.encode(formBody(handoff.fields))),
      );
    } else {
      _controller.loadRequest(getHandoffUri(handoff));
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    if (isPaymentReturnUrl(uri)) {
      _close(true);
      return NavigationDecision.prevent;
    }
    final allowed = request.isMainFrame
        ? isAllowedHandoffNavigation(
            uri,
            handoff: widget.handoff,
            allowLocalHttp: kDebugMode,
          )
        : isAllowedPaymentUrl(uri, allowLocalHttp: kDebugMode);
    return allowed ? NavigationDecision.navigate : NavigationDecision.prevent;
  }

  void _close(bool returned) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(returned);
  }

  @override
  void dispose() {
    unawaited(_controller.clearCache());
    unawaited(_controller.clearLocalStorage());
    unawaited(WebViewCookieManager().clearCookies());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.close),
          tooltip: 'Close payment',
          onPressed: () => _close(false),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Secure payment'),
            Text(
              widget.handoff.url.host,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.appBarTheme.foregroundColor,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_progress < 100) LinearProgressIndicator(value: _progress / 100),
          Expanded(child: WebViewWidget(controller: _controller)),
        ],
      ),
    );
  }
}
