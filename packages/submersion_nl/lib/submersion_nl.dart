import 'package:flutter/services.dart';

/// Thin channel wrapper. Typing and error mapping live in the app layer
/// (ChannelNlEngine), matching the submersion_ocr precedent.
class SubmersionNl {
  static const MethodChannel _channel = MethodChannel('submersion_nl');
  static const EventChannel _download = EventChannel('submersion_nl/download');

  /// One of: available, deviceNotEligible, notEnabled, modelNotReady,
  /// downloadable, downloading, unsupportedLocale.
  static Future<String> availability(String localeTag) async {
    final raw = await _channel.invokeMethod<String>('availability', {
      'locale': localeTag,
    });
    return raw ?? 'modelNotReady';
  }

  /// Warms a session with the fixed instructions and the schema vocabulary.
  static Future<void> prepare(
    String instructions,
    Map<String, Object?> vocabulary,
  ) => _channel.invokeMethod<void>('prepare', {
    'instructions': instructions,
    'vocabulary': vocabulary,
  });

  /// Download progress 0..1 (Android only; Apple emits nothing and completes).
  static Stream<double> download() =>
      _download.receiveBroadcastStream().map((e) => (e as num).toDouble());

  /// Returns the JSON text the model produced. Throws PlatformException with
  /// one of the documented codes on failure.
  static Future<String> compile(String sentence, String localeTag) async {
    final raw = await _channel.invokeMethod<String>('compile', {
      'sentence': sentence,
      'locale': localeTag,
    });
    if (raw == null) {
      throw PlatformException(
        code: 'decoding_failure',
        message: 'empty response',
      );
    }
    return raw;
  }
}
