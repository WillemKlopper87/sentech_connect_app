import 'package:sentech_connect_app/l10n/l10n.dart';
import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:sentech_connect_app/features/catalog_checkout/domain/entities/payment_handoff.dart';
import 'package:sentech_connect_app/features/catalog_checkout/presentation/payment/payment_urls.dart';
import 'package:sentech_connect_app/shared/widgets/secure_screen.dart';
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
    unawaited(_start());
  }

  Future<void> _clearWebData() async {
    try {
      await _controller.clearCache();
      await _controller.clearLocalStorage();
      await WebViewCookieManager().clearCookies();
    } on Object {
      // Best effort: never let a clean-up failure surface (or crash a
      // disposed page).
    }
  }

  Future<void> _start() async {
    final handoff = widget.handoff;
    if (!isAllowedPaymentUrl(handoff.url, allowLocalHttp: kDebugMode)) {
      _close(false);
      return;
    }
    // Start from a clean slate: nothing left from an earlier payment.
    await _clearWebData();
    if (_closed || !mounted) return;
    if (handoff.method == PaymentHandoffMethod.post) {
      await _controller.loadRequest(
        handoff.url,
        method: LoadRequestMethod.post,
        headers: const {'Content-Type': 'application/x-www-form-urlencoded'},
        body: Uint8List.fromList(utf8.encode(formBody(handoff.fields))),
      );
    } else {
      await _controller.loadRequest(getHandoffUri(handoff));
    }
  }

  NavigationDecision _onNavigation(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (uri == null) return NavigationDecision.prevent;
    switch (decideNavigation(
      uri,
      isMainFrame: request.isMainFrame,
      handoff: widget.handoff,
      allowLocalHttp: kDebugMode,
    )) {
      case NavigationVerdict.returned:
        _close(true);
        return NavigationDecision.prevent;
      case NavigationVerdict.allow:
        return NavigationDecision.navigate;
      case NavigationVerdict.block:
        return NavigationDecision.prevent;
    }
  }

  void _close(bool returned) {
    if (_closed || !mounted) return;
    _closed = true;
    Navigator.of(context).pop(returned);
  }

  @override
  void dispose() {
    unawaited(_clearWebData());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // A card form must not show up in screenshots or the recents thumbnail.
    return SecureScreen(
      child: Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.paymentClosePayment,
            onPressed: () => _close(false),
          ),
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(context.l10n.paymentSecurePayment),
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
            if (_progress < 100)
              LinearProgressIndicator(value: _progress / 100),
            Expanded(child: WebViewWidget(controller: _controller)),
          ],
        ),
      ),
    );
  }
}
