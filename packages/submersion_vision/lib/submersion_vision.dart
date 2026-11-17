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

  static Future<void> unload() => _channel.invokeMethod<void>('unload');

  static Future<void> excludeFromBackup(String path) =>
      _channel.invokeMethod<void>('excludeFromBackup', {'path': path});
}
