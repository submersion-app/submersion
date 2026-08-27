import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:submersion/features/ocr_import/data/engines/channel_ocr_engine.dart';
import 'package:submersion/features/ocr_import/data/engines/tesseract_ocr_engine.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

/// Platform-appropriate OCR engine. Uses [defaultTargetPlatform] (not
/// Platform.isX) so tests can override the platform.
///
/// Android (ML Kit), iOS/macOS (Apple Vision), and Windows
/// (Windows.Media.Ocr) all share the submersion_ocr plugin channel;
/// Linux shells out to Tesseract.
final ocrEngineProvider = Provider<OcrEngine>((ref) {
  return switch (defaultTargetPlatform) {
    TargetPlatform.android ||
    TargetPlatform.iOS ||
    TargetPlatform.macOS ||
    TargetPlatform.windows => ChannelOcrEngine(),
    _ => TesseractOcrEngine(),
  };
});

final ocrAvailabilityProvider = FutureProvider<bool>(
  (ref) => ref.watch(ocrEngineProvider).isAvailable,
);
