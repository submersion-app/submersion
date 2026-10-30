import 'dart:io';
import 'dart:typed_data';

import 'package:submersion_transcoder/src/transcode_target.dart';
import 'package:submersion_transcoder/src/video_probe.dart';

/// A genuine engine failure (as opposed to "input this engine cannot
/// handle", which is reported as a null probe). The app-side adapter
/// (PlatformVideoTranscoder) catches this and falls back to uploading the
/// original, because a capability failure (e.g. ffmpeg present but built
/// without libx264) would otherwise fail the queue entry and retry forever.
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

  /// JPEG frames of [source] at each of [times], fitted inside
  /// [maxDimension] square, in the same order; null for a time that could
  /// not be read. Never throws: no engine, no codec or an unreadable file
  /// is all nulls. Read-only: [source] is never modified.
  ///
  /// By default a nearby keyframe will do (fast, and close enough for
  /// colour statistics); [exact] asks for the very frame at each time, for
  /// picking a white point on the paused frame the diver is looking at.
  Future<List<Uint8List?>> extractFrames({
    required File source,
    required List<Duration> times,
    int maxDimension = 160,
    bool exact = false,
  });
}
