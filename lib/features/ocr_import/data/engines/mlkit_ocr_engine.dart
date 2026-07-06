import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path_provider/path_provider.dart';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

/// One OcrTextBlock per ML Kit LINE (not block): lines are the label/value
/// granularity the binder needs; blocks merge whole columns.
OcrResult mapRecognizedText(RecognizedText recognized, Size imageSize) {
  final blocks = <OcrTextBlock>[
    for (final block in recognized.blocks)
      for (final line in block.lines)
        OcrTextBlock(
          text: line.text,
          boundingBox: line.boundingBox,
          confidence: line.confidence,
        ),
  ];
  return OcrResult(blocks: blocks, imageSize: imageSize);
}

class MlkitOcrEngine implements OcrEngine {
  @override
  Future<bool> get isAvailable async => Platform.isAndroid;

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    // ML Kit needs a file path; write bytes to a temp file.
    final tmp = await getTemporaryDirectory();
    final file = File(
      '${tmp.path}/ocr_${DateTime.now().millisecondsSinceEpoch}.jpg',
    );
    await file.writeAsBytes(imageBytes);
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final input = InputImage.fromFilePath(file.path);
      final recognized = await recognizer.processImage(input);
      final decoded = await decodeImageFromList(imageBytes);
      return mapRecognizedText(
        recognized,
        Size(decoded.width.toDouble(), decoded.height.toDouble()),
      );
    } finally {
      await recognizer.close();
      await file.delete();
    }
  }
}
