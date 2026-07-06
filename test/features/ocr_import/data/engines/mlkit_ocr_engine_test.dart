import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:submersion/features/ocr_import/data/engines/mlkit_ocr_engine.dart';

void main() {
  test('maps ML Kit lines to OcrTextBlocks with pixel rects', () {
    final recognized = RecognizedText.fromJson({
      'text': 'DEPTH 69',
      'blocks': [
        {
          'text': 'DEPTH 69',
          'rect': {'left': 10.0, 'top': 20.0, 'right': 110.0, 'bottom': 40.0},
          'recognizedLanguages': ['en'],
          'points': [],
          'lines': [
            {
              'text': 'DEPTH',
              'rect': {
                'left': 10.0,
                'top': 20.0,
                'right': 60.0,
                'bottom': 32.0,
              },
              'recognizedLanguages': ['en'],
              'points': [],
              'confidence': 0.9,
              'angle': 0.0,
              'elements': [],
            },
            {
              'text': '69',
              'rect': {
                'left': 70.0,
                'top': 20.0,
                'right': 90.0,
                'bottom': 32.0,
              },
              'recognizedLanguages': ['en'],
              'points': [],
              'confidence': 0.8,
              'angle': 0.0,
              'elements': [],
            },
          ],
        },
      ],
    });
    final result = mapRecognizedText(recognized, const Size(1000, 1400));
    expect(result.blocks, hasLength(2));
    expect(result.blocks.first.text, 'DEPTH');
    expect(
      result.blocks.first.boundingBox,
      const Rect.fromLTRB(10, 20, 60, 32),
    );
    expect(result.blocks.first.confidence, 0.9);
    expect(result.imageSize, const Size(1000, 1400));
  });
}
