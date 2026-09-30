import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Turns Android's `FLAG_SECURE` on/off (blocks screenshots, screen
/// recording and the recent-apps thumbnail) via a tiny MethodChannel handled
/// in `MainActivity.kt`. Reference counted, so two sensitive screens alive at
/// once never switch protection off under each other. No-op off Android.
class ScreenSecurity {
  ScreenSecurity._();

  static const channel = MethodChannel('za.co.sentech.sentech_connect_app/platform');
  static int _holders = 0;

  static bool get isProtected => _holders > 0;

  static void acquire() {
    _holders++;
    if (_holders == 1) _set(true);
  }

  static void release() {
    if (_holders == 0) return;
    _holders--;
    if (_holders == 0) _set(false);
  }

  @visibleForTesting
  static void resetForTest() => _holders = 0;

  static void _set(bool enabled) {
    // Fire and forget: protection state must never block the UI, and a
    // platform without the handler (iOS, web, desktop) simply ignores it.
    unawaited(channel.invokeMethod<void>('setSecure', {'enabled': enabled}).catchError((Object _) {}));
  }
}

/// Keeps [child]'s screen capture-protected while it is actually visible.
/// Uses the same tab-visibility signal as the voucher scanner (`TickerMode`),
/// so a tab kept alive in the bottom-nav `IndexedStack` only protects the
/// window while that tab is showing.
class SecureScreen extends StatefulWidget {
  const SecureScreen({super.key, required this.child});

  final Widget child;

  @override
  State<SecureScreen> createState() => _SecureScreenState();
}

class _SecureScreenState extends State<SecureScreen> {
  bool _holding = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible && !_holding) {
      _holding = true;
      ScreenSecurity.acquire();
    } else if (!visible && _holding) {
      _holding = false;
      ScreenSecurity.release();
    }
  }

  @override
  void dispose() {
    if (_holding) ScreenSecurity.release();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
