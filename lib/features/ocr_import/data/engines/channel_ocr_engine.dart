import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion_ocr/submersion_ocr.dart';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

/// iOS/macOS (Apple Vision) and Windows (Windows.Media.Ocr) via the
/// submersion_ocr plugin. The native side owns coordinate normalization.
class ChannelOcrEngine implements OcrEngine {
  @override
  Future<bool> get isAvailable async => true;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    final maps = await SubmersionOcr.recognizeText(imageBytes);
    if (maps.isEmpty) {
      return const OcrResult(blocks: [], imageSize: Size.zero);
    }
    final blocks = [
      for (final m in maps)
        OcrTextBlock(
          text: m['text'] as String,
          boundingBox: Rect.fromLTWH(
            (m['left'] as num).toDouble(),
            (m['top'] as num).toDouble(),
            (m['width'] as num).toDouble(),
            (m['height'] as num).toDouble(),
          ),
          confidence: (m['confidence'] as num?)?.toDouble(),
        ),
    ];
    final first = maps.first;
    return OcrResult(
      blocks: blocks,
      imageSize: Size(
        (first['imageWidth'] as num).toDouble(),
        (first['imageHeight'] as num).toDouble(),
      ),
    );
  }
}
