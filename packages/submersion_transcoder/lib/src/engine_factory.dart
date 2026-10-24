import 'dart:io';

import 'package:submersion_transcoder/src/channel_transcode_engine.dart';
import 'package:submersion_transcoder/src/color_encoder.dart';
import 'package:submersion_transcoder/src/linux_ffmpeg_engine.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';

/// The engine for the current platform, or null when none exists yet.
/// Apple (iOS/macOS) = AVFoundation, Android = Media3, and Windows = Media
/// Foundation via WinRT, all through the shared [ChannelTranscodeEngine];
/// Linux = system ffmpeg.
///
/// This factory lives in its own file so the [TranscodeEngine] interface and
/// the concrete engines it selects can stay on a one-way dependency edge
/// (engine -> interface). Wiring the factory into the interface file instead
/// would make transcode_engine.dart and the engine files import each other.
TranscodeEngine? engineForThisPlatform() {
  if (Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isAndroid ||
      Platform.isWindows) {
    return ChannelTranscodeEngine();
  }
  if (Platform.isLinux) return LinuxFfmpegEngine();
  return null;
}

/// The colour encoder for the current platform (issue #3521), or null where
/// there is none: iOS, macOS, Android and Windows have one; Linux does not,
/// since Share cannot hand files over there (issue #3606).
ColorEncoder? colorEncoderForThisPlatform() {
  if (Platform.isIOS ||
      Platform.isMacOS ||
      Platform.isAndroid ||
      Platform.isWindows) {
    return ChannelTranscodeEngine();
  }
  return null;
}
