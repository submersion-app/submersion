import 'dart:io';

import 'package:submersion_transcoder/src/channel_transcode_engine.dart';
import 'package:submersion_transcoder/src/linux_ffmpeg_engine.dart';
import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// A genuine engine failure (as opposed to "input this engine cannot
/// handle", which is reported as a null probe). Callers surface it to the
/// transfer queue's normal retry/backoff.
class TranscodeException implements Exception {
  const TranscodeException(this.message);
  final String message;
  @override
  String toString() => 'TranscodeException: $message';
}

/// One platform transcoder. Contract:
/// - [transcode] writes to '<output>.tmp' (overwriting any debris) and
///   renames to [output] only on success, so an existing [output] is always
///   a complete rendition.
/// - Throws [TranscodeException] on engine failure; never leaves a .tmp.
abstract class TranscodeEngine {
  Future<bool> isAvailable();
  Future<VideoProbe?> probe(File source);
  Future<void> transcode({
    required File source,
    required File output,
    required TranscodeTarget target,
    VideoProbe? probe,
    void Function(double fraction)? onProgress,
  });
}

/// The engine for the current platform, or null when none exists yet.
/// Apple (iOS/macOS) = AVFoundation, Android = Media3, and Windows = Media
/// Foundation via WinRT, all through the shared [ChannelTranscodeEngine];
/// Linux = system ffmpeg.
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
