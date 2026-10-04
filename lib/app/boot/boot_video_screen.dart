import 'package:sentech_connect_app/l10n/l10n.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sentech_connect_app/app/boot/boot_video_config.dart';
import 'package:sentech_connect_app/app/boot/boot_video_controller.dart';
import 'package:sentech_connect_app/shared/widgets/sentech_logo.dart';

/// Full-screen boot video, shown once per cold start after the native splash.
///
/// [initDone] is the app's own start-up work, running in parallel; it is
/// never delayed by the video. [onComplete] fires exactly once, when the
/// video is over (finished, skipped, failed, timed out, or replaced by the
/// static logo under reduce-motion) AND [initDone] has completed. A failing
/// [initDone] also counts as done: the owner of the future reports errors.
///
/// Uses bundled localization copy and is theme-free (it sits above the app, like
/// the startup error screen), and it never shows an error: any problem with
/// the video just means moving on.
class BootVideoScreen extends StatefulWidget {
  const BootVideoScreen({
    super.key,
    required this.initDone,
    required this.onComplete,
    this.controllerFactory,
    this.showStaticLogo = false,
    this.onPlaybackStarted,
    this.skipDelay = bootVideoSkipDelay,
    this.watchdog = bootVideoWatchdog,
    this.reduceMotionHold = bootVideoReduceMotionHold,
  });

  final Future<void> initDone;
  final VoidCallback onComplete;

  /// `null` means "no video" (tests, unsupported platforms): the screen
  /// completes as soon as [initDone] does.
  final BootVideoControllerFactory? controllerFactory;
  final bool showStaticLogo;
  final VoidCallback? onPlaybackStarted;
  final Duration skipDelay;
  final Duration watchdog;
  final Duration reduceMotionHold;

  @override
  State<BootVideoScreen> createState() => _BootVideoScreenState();
}

class _BootVideoScreenState extends State<BootVideoScreen> {
  BootVideoController? _controller;
  Timer? _skipTimer;
  Timer? _watchdogTimer;
  Timer? _holdTimer;
  bool _skipEnabled = false;
  bool _videoDone = false;
  bool _initDone = false;
  bool _completed = false;
  bool _started = false;
  bool _showVideo = false;

  @override
  void initState() {
    super.initState();
    unawaited(_awaitInit());
  }

  Future<void> _awaitInit() async {
    try {
      await widget.initDone;
    } catch (_) {
      // Reported by whoever owns the future; the video must not hang on it.
    }
    _initDone = true;
    _maybeComplete();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Decided once: a setting flipped mid-launch is not worth reacting to.
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduceMotion || widget.showStaticLogo) {
      _holdTimer = Timer(widget.reduceMotionHold, _finishVideo);
    } else if (widget.controllerFactory == null) {
      _finishVideo();
    } else {
      _skipTimer = Timer(widget.skipDelay, () {
        if (mounted) setState(() => _skipEnabled = true);
      });
      _watchdogTimer = Timer(widget.watchdog, _finishVideo);
      unawaited(_startVideo());
    }
  }

  Future<void> _startVideo() async {
    try {
      final controller = widget.controllerFactory!();
      _controller = controller;
      await controller.initialize();
      if (!mounted || _videoDone) return;
      controller.addListener(_onVideoChanged);
      await controller.setVolume(bootVideoSoundEnabled ? 1 : 0);
      await controller.play();
      if (!mounted || _videoDone) return;
      widget.onPlaybackStarted?.call();
      setState(() => _showVideo = true);
    } catch (_) {
      // Any plugin/codec/asset problem: no error UI, just move on.
      _finishVideo();
    }
  }

  void _onVideoChanged() {
    final controller = _controller;
    if (controller == null || _videoDone) return;
    final total = controller.duration;
    if (controller.hasError ||
        (total > Duration.zero && controller.position >= total)) {
      _finishVideo();
    }
  }

  void _finishVideo() {
    if (_videoDone) return;
    _videoDone = true;
    _skipTimer?.cancel();
    _watchdogTimer?.cancel();
    _holdTimer?.cancel();
    _maybeComplete();
  }

  void _maybeComplete() {
    if (!mounted || _completed || !_videoDone || !_initDone) return;
    _completed = true;
    widget.onComplete();
  }

  void _skip() {
    if (_skipEnabled) _finishVideo();
  }

  @override
  void dispose() {
    _skipTimer?.cancel();
    _watchdogTimer?.cancel();
    _holdTimer?.cancel();
    final controller = _controller;
    if (controller != null) {
      controller.removeListener(_onVideoChanged);
      unawaited(controller.dispose().then((_) {}, onError: (Object _) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion =
        (MediaQuery.maybeDisableAnimationsOf(context) ?? false) ||
        widget.showStaticLogo;
    final controller = _controller;
    return Localizations(
      locale: const Locale('en'),
      delegates: const [
        DefaultMaterialLocalizations.delegate,
        DefaultWidgetsLocalizations.delegate,
      ],
      child: Semantics(
        container: true,
        label: context.l10n.bootSentechConnectIsStarting,
        child: Material(
          color: bootVideoBackground,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _skip,
            child: Stack(
              fit: StackFit.expand,
              children: [
                if (reduceMotion)
                  const Center(
                    child: ExcludeSemantics(
                      child: KeyedSubtree(
                        key: Key('boot-logo'),
                        child: SentechLogo(height: 56),
                      ),
                    ),
                  )
                else if (_showVideo && controller != null)
                  // After the video ends the last frame stays up while init finishes.
                  ExcludeSemantics(
                    child: KeyedSubtree(
                      key: const Key('boot-video'),
                      child: _CoverVideo(controller: controller),
                    ),
                  ),
                if (!reduceMotion && widget.controllerFactory != null)
                  SafeArea(
                    child: Align(
                      alignment: Alignment.topRight,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Semantics(
                          container: true,
                          button: true,
                          enabled: _skipEnabled,
                          label: context.l10n.bootSkipIntro,
                          excludeSemantics: true,
                          onTap: _skipEnabled ? _skip : null,
                          child: Opacity(
                            opacity: _skipEnabled ? 1 : 0.55,
                            child: ConstrainedBox(
                              key: const Key('boot-skip'),
                              constraints: const BoxConstraints(
                                minWidth: 48,
                                minHeight: 48,
                              ),
                              child: ActionChip(
                                onPressed: _skipEnabled ? _skip : null,
                                backgroundColor: const Color(0xB30D2033),
                                disabledColor: const Color(0xB30D2033),
                                labelStyle: const TextStyle(
                                  color: Colors.white,
                                ),
                                side: BorderSide.none,
                                shape: const StadiumBorder(),
                                labelPadding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                ),
                                materialTapTargetSize:
                                    MaterialTapTargetSize.padded,
                                visualDensity: VisualDensity.standard,
                                label: Text(context.l10n.bootSkip),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CoverVideo extends StatelessWidget {
  const _CoverVideo({required this.controller});

  final BootVideoController controller;

  @override
  Widget build(BuildContext context) {
    final size = controller.size;
    if (size.isEmpty) return const SizedBox.shrink();
    return SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        clipBehavior: Clip.hardEdge,
        child: SizedBox(
          width: size.width,
          height: size.height,
          child: controller.buildVideo(context),
        ),
      ),
    );
  }
}
