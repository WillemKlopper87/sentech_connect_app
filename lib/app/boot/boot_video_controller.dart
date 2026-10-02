import 'package:flutter/widgets.dart';
import 'package:sentech_connect_app/app/boot/boot_video_config.dart';
import 'package:video_player/video_player.dart';

/// The slice of a video player the boot screen needs, so widget tests can
/// use a fake and never touch the platform plugin.
abstract class BootVideoController {
  Future<void> initialize();
  Future<void> play();
  Future<void> setVolume(double volume);

  bool get isInitialized;
  bool get hasError;
  Duration get position;
  Duration get duration;

  /// Natural pixel size of the video (valid once initialized).
  Size get size;

  void addListener(VoidCallback listener);
  void removeListener(VoidCallback listener);
  Future<void> dispose();

  /// The video surface, unsized (the screen fits it).
  Widget buildVideo(BuildContext context);
}

typedef BootVideoControllerFactory = BootVideoController Function();

/// The real thing: the bundled asset through `video_player`. Nothing here
/// touches the network.
BootVideoController createAssetBootVideoController() =>
    _AssetBootVideoController(
      VideoPlayerController.asset(
        bootVideoAsset,
        // Do not interrupt (or be interrupted by) the user's music/podcast.
        videoPlayerOptions: VideoPlayerOptions(mixWithOthers: true),
      ),
    );

class _AssetBootVideoController implements BootVideoController {
  _AssetBootVideoController(this._inner);

  final VideoPlayerController _inner;

  @override
  Future<void> initialize() => _inner.initialize();

  @override
  Future<void> play() => _inner.play();

  @override
  Future<void> setVolume(double volume) => _inner.setVolume(volume);

  @override
  bool get isInitialized => _inner.value.isInitialized;

  @override
  bool get hasError => _inner.value.hasError;

  @override
  Duration get position => _inner.value.position;

  @override
  Duration get duration => _inner.value.duration;

  @override
  Size get size => _inner.value.size;

  @override
  void addListener(VoidCallback listener) => _inner.addListener(listener);

  @override
  void removeListener(VoidCallback listener) => _inner.removeListener(listener);

  @override
  Future<void> dispose() => _inner.dispose();

  @override
  Widget buildVideo(BuildContext context) => VideoPlayer(_inner);
}
