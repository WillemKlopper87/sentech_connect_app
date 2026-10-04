import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/app/boot/boot_video_controller.dart';
import 'package:sentech_connect_app/app/boot/boot_video_screen.dart';
import 'package:sentech_connect_app/app/startup_error_app.dart';
import 'package:sentech_connect_app/core/local/app_preferences.dart';

/// Root of the running app: plays the boot video over the app while the app
/// is prepared (and, once built, starts up) underneath, in parallel.
///
/// [app] is the start-up work in flight (restore session, load preferences)
/// resolving to the app widget. The overlay goes away only when the video is
/// over AND [app] has resolved. If [app] fails the minimal startup error app
/// replaces everything, exactly as for an invalid configuration.
class BootHost extends StatefulWidget {
  const BootHost({
    super.key,
    required this.app,
    this.controllerFactory,
    this.bootVideoSeen,
    this.markBootVideoSeen,
    this.onPreferenceError,
    this.onError,
  });

  final Future<Widget> app;

  /// `null` skips the video entirely (the app shows as soon as it is ready).
  final BootVideoControllerFactory? controllerFactory;
  final Future<bool>? bootVideoSeen;
  final Future<void> Function()? markBootVideoSeen;
  final void Function(Object error, StackTrace stack)? onPreferenceError;

  /// Receives a start-up failure for reporting (already scrubbed upstream).
  final void Function(Object error, StackTrace stack)? onError;

  @override
  State<BootHost> createState() => _BootHostState();
}

class _BootHostState extends State<BootHost> {
  Widget? _app;
  bool _failed = false;
  bool _overlayGone = false;
  bool? _seen;
  late final Future<void> _initDone;

  @override
  void initState() {
    super.initState();
    unawaited(_loadSeen());
    _initDone = widget.app.then<void>(
      (app) {
        if (mounted) setState(() => _app = app);
      },
      onError: (Object error, StackTrace stack) {
        widget.onError?.call(error, stack);
        if (mounted) setState(() => _failed = true);
      },
    );
  }

  Future<void> _loadSeen() async {
    try {
      final seen =
          await (widget.bootVideoSeen ?? AppPreferences.loadBootVideoSeen());
      if (mounted) setState(() => _seen = seen);
    } catch (_) {
      // Unknown preference: show the static logo without creating a player.
      if (mounted) setState(() => _seen = true);
    }
  }

  void _markSeen() {
    Future<void> write;
    try {
      write = (widget.markBootVideoSeen ?? AppPreferences.markBootVideoSeen)();
    } catch (error, stack) {
      widget.onPreferenceError?.call(error, stack);
      return;
    }
    unawaited(
      write.then<void>(
        (_) {},
        onError: (Object error, StackTrace stack) =>
            widget.onPreferenceError?.call(error, stack),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_failed) return buildStartupErrorApp();
    final app = _app;
    // Above any MaterialApp, so supply the ambient widgets the overlay needs.
    return Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery.fromView(
        view: View.of(context),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (app != null && _seen != null)
              Positioned.fill(
                // Underneath the video: not tappable and hidden from
                // screen readers until the overlay is gone.
                child: IgnorePointer(
                  ignoring: !_overlayGone,
                  child: ExcludeSemantics(excluding: !_overlayGone, child: app),
                ),
              ),
            if (!_overlayGone && _seen != null)
              Positioned.fill(
                child: BootVideoScreen(
                  initDone: _initDone,
                  controllerFactory: _seen! ? null : widget.controllerFactory,
                  showStaticLogo: _seen! && widget.controllerFactory != null,
                  onPlaybackStarted: _markSeen,
                  onComplete: () {
                    if (mounted && !_failed) {
                      setState(() => _overlayGone = true);
                    }
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}
