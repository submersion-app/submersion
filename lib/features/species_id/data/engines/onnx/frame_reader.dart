import 'package:flutter/services.dart';

import 'package:submersion/features/species_id/data/engines/onnx/pipeline/pixels.dart';
import 'package:submersion/features/species_id/domain/services/vision_engine.dart';

/// A decoded video frame and when it is shown.
class VideoFrame {
  const VideoFrame(this.ms, this.image);

  final int ms;
  final RgbaImage image;
}

/// An opened video: its handle, its size as the player shows it (after its
/// rotation), and its length.
typedef OpenedVideo = ({int handle, int width, int height, int durationMs});

/// What the system says about the device while a video is scanned.
typedef DeviceState = ({
  bool thermalSevere,
  bool lowMemory,
  int availableBytes,
});

/// Reads video frames for the ONNX engine's video passes. Native on Android
/// (Kotlin) and Windows (Media Foundation); it knows nothing about models.
abstract interface class FrameReader {
  /// Opens the video at [path], a file path or (Android) a `content://` URI.
  Future<OpenedVideo> open(String path);

  /// Pass 1: decodes on in order to the first frame shown at or after
  /// [atOrAfterMs], rotated as shown, the longer side at most [maxSide];
  /// null at the end of the video. Windows reads frames in order and gives
  /// each one's own time. Android's retriever has no "at or after" seek: it
  /// gives the frame closest to [atOrAfterMs], at most half a frame
  /// earlier, reported at the time asked; the engine samples a quarter of
  /// a second or more apart, so half a frame (about 17 ms at 30 frames a
  /// second) moves no track.
  Future<VideoFrame?> next(
    int handle, {
    required int atOrAfterMs,
    required int maxSide,
  });

  /// Pass 2: the exact frame at [ms], the longer side at most [maxSide];
  /// null when it cannot be read.
  Future<RgbaImage?> frameAt(int handle, int ms, {required int maxSide});

  Future<void> close(int handle);

  /// Whether the device is too hot, and how its memory stands.
  Future<DeviceState> deviceState();
}

/// [FrameReader] over the `submersion_vision/frames` channel.
class ChannelFrameReader implements FrameReader {
  const ChannelFrameReader();

  static const _channel = MethodChannel('submersion_vision/frames');

  @override
  Future<OpenedVideo> open(String path) async {
    final reply = await _call<Map<Object?, Object?>>('open', {'path': path});
    return (
      handle: _int(reply?['handle']),
      width: _int(reply?['width']),
      height: _int(reply?['height']),
      durationMs: _int(reply?['durationMs']),
    );
  }

  @override
  Future<VideoFrame?> next(
    int handle, {
    required int atOrAfterMs,
    required int maxSide,
  }) async {
    final reply = await _call<Map<Object?, Object?>>('next', {
      'handle': handle,
      'atOrAfterMs': atOrAfterMs,
      'maxSide': maxSide,
    });
    if (reply == null) return null;
    return VideoFrame(_int(reply['ms']), _image(reply));
  }

  @override
  Future<RgbaImage?> frameAt(int handle, int ms, {required int maxSide}) async {
    final reply = await _call<Map<Object?, Object?>>('frameAt', {
      'handle': handle,
      'ms': ms,
      'maxSide': maxSide,
    });
    return reply == null ? null : _image(reply);
  }

  @override
  Future<void> close(int handle) => _call<void>('close', {'handle': handle});

  @override
  Future<DeviceState> deviceState() async {
    final reply = await _call<Map<Object?, Object?>>('deviceState', null);
    return (
      thermalSevere: reply?['thermalSevere'] == true,
      lowMemory: reply?['lowMemory'] == true,
      availableBytes: _int(reply?['availableBytes']),
    );
  }

  static Future<T?> _call<T>(String method, Object? arguments) async {
    try {
      return await _channel.invokeMethod<T>(method, arguments);
    } on MissingPluginException {
      throw const VisionEngineException('unsupported', 'no frame reader');
    } on PlatformException catch (e) {
      throw VisionEngineException(e.code, e.message);
    }
  }

  /// The frame in [reply]; a reply whose pixels do not fill its size is a
  /// decode failure here, rather than an index error in the worker.
  static RgbaImage _image(Map<Object?, Object?> reply) {
    final rgba = reply['rgba'];
    final width = _int(reply['width']), height = _int(reply['height']);
    if (width <= 0 ||
        height <= 0 ||
        rgba is! Uint8List ||
        rgba.length != width * height * 4) {
      throw const VisionEngineException(
        'decode_failed',
        'the frame reader returned a frame of the wrong size',
      );
    }
    return RgbaImage(width, height, rgba);
  }

  static int _int(Object? v) => v is num ? v.toInt() : 0;
}
