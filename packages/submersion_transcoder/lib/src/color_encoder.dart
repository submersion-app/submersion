import 'dart:async';
import 'dart:io';

import 'package:submersion_transcoder/src/color_timeline.dart';
import 'package:submersion_transcoder/src/transcode_engine.dart';

/// A request to stop a colour encode, made by whoever started it.
class ColorEncodeCancel {
  final _requested = Completer<void>();

  bool get isCancelled => _requested.isCompleted;

  /// Completes when [cancel] is first called.
  Future<void> get whenCancelled => _requested.future;

  void cancel() {
    if (!_requested.isCompleted) _requested.complete();
  }
}

/// The encode was stopped before it finished: by [ColorEncodeCancel], or by
/// the system (an iOS app sent to the background). No output was written.
class TranscodeCancelledException implements Exception {
  const TranscodeCancelledException();
  @override
  String toString() => 'TranscodeCancelledException';
}

/// This device cannot decode or encode the source as the encode requires
/// (its codec, its size and frame rate, or keeping it HDR).
class TranscodeUnsupportedException extends TranscodeException {
  const TranscodeUnsupportedException(super.message);
  @override
  String toString() => 'TranscodeUnsupportedException: $message';
}

/// Re-encodes a video with a colour correction applied to every frame
/// (issue #3521). Keeps the source's codec family (HEVC, or H.264; anything
/// else becomes HEVC), dimensions, orientation, frame rate, bit depth and
/// HDR, its audio, and its recording date and location.
///
/// Same file contract as [TranscodeEngine.transcode]: writes
/// '<output>.tmp' and renames it to [output] only on success, never leaves
/// a '.tmp'. Throws [TranscodeCancelledException] when stopped,
/// [TranscodeUnsupportedException] when the device cannot do it, and
/// [TranscodeException] on any other failure.
abstract interface class ColorEncoder {
  Future<void> encodeWithColor({
    required File source,
    required File output,
    required ColorTimeline timeline,
    ColorEncodeCancel? cancel,
    void Function(double fraction)? onProgress,
  });
}
