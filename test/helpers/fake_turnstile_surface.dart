import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_config.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_message.dart';
import 'package:sentech_connect_app/core/security/turnstile/turnstile_surface.dart';

/// A stand-in for the WebView: the test pushes the messages the page would
/// send through the JavaScript channel.
class FakeTurnstileSurface implements TurnstileSurface {
  final _controller = StreamController<TurnstileMessage>.broadcast(sync: true);
  var loads = 0;
  var resets = 0;
  var disposed = false;
  Object? loadError;
  Object? resetError;

  /// What the page does on load / reset (default: nothing, the test drives it).
  void Function(FakeTurnstileSurface surface)? onLoad;
  void Function(FakeTurnstileSurface surface)? onReset;

  void send(TurnstileMessage message) {
    if (!_controller.isClosed) _controller.add(message);
  }

  /// Sends the raw JSON string like the JavaScript channel would.
  void sendRaw(String raw) {
    final parsed = TurnstileMessage.parse(raw);
    if (parsed != null) send(parsed);
  }

  @override
  Stream<TurnstileMessage> get messages => _controller.stream;

  @override
  Future<void> load(TurnstileConfig config) async {
    loads++;
    if (loadError != null) throw loadError!;
    onLoad?.call(this);
  }

  @override
  Future<void> reset(TurnstileConfig config) async {
    resets++;
    if (resetError != null) throw resetError!;
    onReset?.call(this);
  }

  @override
  Widget buildView(BuildContext context) => const SizedBox(key: Key('fakeTurnstileView'), height: 60);

  @override
  Future<void> dispose() async {
    disposed = true;
    await _controller.close();
  }
}

const testTurnstileToken = '0.SECRETTOKEN-abcdefghijklmnopqrstuvwxyz0123456789';
