import 'package:flutter/services.dart';

class SubmersionOcr {
  static const MethodChannel _channel = MethodChannel('submersion_ocr');

  /// Returns one map per recognized text line:
  /// {text, left, top, width, height, confidence?, imageWidth, imageHeight}
  /// Coordinates are top-left-origin pixels.
  static Future<List<Map<String, dynamic>>> recognizeText(
    Uint8List imageBytes,
  ) async {
    final raw = await _channel.invokeListMethod<Object?>('recognizeText', {
      'image': imageBytes,
    });
    return (raw ?? const [])
        .map((e) => Map<String, dynamic>.from(e! as Map))
        .toList();
  }
}
