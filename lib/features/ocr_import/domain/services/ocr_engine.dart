import 'dart:typed_data';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';

/// Pixels in, positioned text out. Implementations must be dumb:
/// no parsing, no field logic — that all lives in LogbookParser.
abstract class OcrEngine {
  /// Whether the engine can run on this device (e.g. Tesseract installed).
  Future<bool> get isAvailable;

  Future<OcrResult> recognize(Uint8List imageBytes);
}
