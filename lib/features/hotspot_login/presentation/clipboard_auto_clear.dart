import 'dart:async';

import 'package:flutter/services.dart';

/// Puts a secret on the clipboard and takes it off again after [delay]
/// (default one minute), but only if the clipboard still holds that same text,
/// so something the customer copied since is never wiped. [dispose] clears at
/// once (the secret does not outlive the screen). Where the platform refuses a
/// clipboard read (Android 10+ in the background) the clear is skipped, never
/// forced.
class ClipboardAutoClear {
  ClipboardAutoClear({this.delay = const Duration(seconds: 60)});

  final Duration delay;
  Timer? _timer;
  String? _held;

  Future<void> copy(String text) async {
    _timer?.cancel();
    _held = text;
    await Clipboard.setData(ClipboardData(text: text));
    _timer = Timer(delay, clearNow);
  }

  Future<void> clearNow() async {
    _timer?.cancel();
    final held = _held;
    _held = null;
    if (held == null) return;
    try {
      final current = (await Clipboard.getData(Clipboard.kTextPlain))?.text;
      if (current == held) {
        await Clipboard.setData(const ClipboardData(text: ''));
      }
    } on Object {
      // Clipboard not readable now: leave it.
    }
  }

  void dispose() => unawaited(clearNow());
}
