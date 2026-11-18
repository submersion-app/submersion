import 'package:flutter/services.dart';

/// The `submersion_vision` method channel: a fish detector and an image
/// embedding model, run on the device. See the app's `VisionEngine` for the
/// meaning of each call.
class SubmersionVision {
  static const MethodChannel _channel = MethodChannel('submersion_vision');

  /// `available`, `unsupportedPlatform` or `deviceNotEligible`.
  static Future<String?> availability() =>
      _channel.invokeMethod<String>('availability');

  static Future<void> load(Map<String, Object?> models) =>
      _channel.invokeMethod<void>('load', models);

  /// `{imageWidth, imageHeight, detections: [{x, y, width, height, score,
  /// pixelWidth, pixelHeight, crop, embedding}]}`.
  static Future<Map<Object?, Object?>?> analyze(Map<String, Object?> source) =>
      _channel.invokeMethod<Map<Object?, Object?>>('analyze', source);

  /// `{width, height, durationMs, frames: [{ms, boxes: [{x, y, width,
  /// height, score}]}]}`.
  static Future<Map<Object?, Object?>?> detectVideo(
    Map<String, Object?> args,
  ) => _channel.invokeMethod<Map<Object?, Object?>>('detectVideo', args);

  /// One entry per moment: null, or `{pixelWidth, pixelHeight, crop,
  /// embedding}`.
  static Future<List<Object?>?> embedMoments(Map<String, Object?> args) =>
      _channel.invokeMethod<List<Object?>>('embedMoments', args);

  static Future<void> unload() => _channel.invokeMethod<void>('unload');

  /// `{footprint, footprintPeak, available, neuralCounted, neuralNotCounted,
  /// neuralNotCountedPeak}` in bytes; a key the platform does not report is
  /// left out.
  static Future<Map<Object?, Object?>?> memory() =>
      _channel.invokeMethod<Map<Object?, Object?>>('memory');

  static Future<void> excludeFromBackup(String path) =>
      _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
}
