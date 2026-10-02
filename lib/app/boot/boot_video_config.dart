import 'package:flutter/painting.dart';

/// Boot video settings. The one switch to flip to give the intro sound.
///
/// Ruling: the boot video is muted by default. An app that blasts audio at
/// launch (in a meeting, at night, on a shared phone) is a worse first
/// impression than a silent logo reveal, and the track is not needed for the
/// reveal to read. Flip this single flag to enable the audio track.
const bool bootVideoSoundEnabled = false;

/// `--dart-define=BOOT_VIDEO=false` turns the boot video off for a build
/// (screenshots, automated runs). Default on.
const bool bootVideoEnabled = bool.fromEnvironment(
  'BOOT_VIDEO',
  defaultValue: true,
);

/// Bundled source, declared in pubspec.yaml.
const String bootVideoAsset = 'assets/brand/boot/sentech_boot.mp4';

/// Edge colour sampled (ffmpeg, frame 0) from the video, which has a light
/// grey vignette: the area shown before the first frame is decoded, so the
/// hand-off from the white native splash has no flash.
const Color bootVideoBackground = Color(0xFFDAD9DB);

/// Skip is enabled only after this long, so a stray tap at launch does not
/// cut the logo reveal.
const Duration bootVideoSkipDelay = Duration(milliseconds: 1500);

/// Hard stop: a video that has not finished by now is abandoned.
const Duration bootVideoWatchdog = Duration(seconds: 12);

/// How long the static logo shows when the OS asks for reduced motion.
const Duration bootVideoReduceMotionHold = Duration(milliseconds: 800);
