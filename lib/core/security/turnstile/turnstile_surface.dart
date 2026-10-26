import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';

/// Where the widget runs. The real one is a WebView; tests use a fake that
/// pushes [TurnstileMessage]s, so the check logic is testable without a
/// WebView or a device.
abstract interface class TurnstileSurface {
  /// Messages from the page (token, widget errors, page load errors).
  Stream<TurnstileMessage> get messages;

  /// Loads the widget page for [config]. Called once per check.
  Future<void> load(TurnstileConfig config);

  /// Asks the widget for a fresh challenge (the previous token, if any, is
  /// void). Falls back to a reload when the page is not usable.
  Future<void> reset(TurnstileConfig config);

  /// The view to show in the sheet.
  Widget buildView(BuildContext context);

  /// Releases the view and clears everything the page stored (cache, local
  /// storage, cookies). Safe to call twice.
  Future<void> dispose();
}
