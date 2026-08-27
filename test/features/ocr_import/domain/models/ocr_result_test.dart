import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';

void main() {
  group('OcrTextBlock', () {
    test('exposes center of bounding box', () {
      const block = OcrTextBlock(
        text: 'DEPTH',
        boundingBox: Rect.fromLTWH(10, 20, 40, 10),
      );
      expect(block.center, const Offset(30, 25));
    });

    test('height reflects bounding box height', () {
      const block = OcrTextBlock(
        text: '69',
        boundingBox: Rect.fromLTWH(0, 0, 20, 14),
      );
      expect(block.height, 14);
    });
  });

  group('equality', () {
    test('identical blocks and results are equal', () {
      const a = OcrTextBlock(
        text: 'DEPTH',
        boundingBox: Rect.fromLTWH(10, 20, 40, 10),
        confidence: 0.9,
      );
      const b = OcrTextBlock(
        text: 'DEPTH',
        boundingBox: Rect.fromLTWH(10, 20, 40, 10),
        confidence: 0.9,
      );
      expect(a, b);
      // Non-const on purpose: identical const instances short-circuit
      // Equatable's == and props would never be evaluated.
      // ignore: prefer_const_constructors
      final resultA = OcrResult(blocks: [a], imageSize: const Size(100, 100));
      // ignore: prefer_const_constructors
      final resultB = OcrResult(blocks: [b], imageSize: const Size(100, 100));
      expect(resultA, resultB);
    });

    test('isEmpty reflects block count', () {
      expect(const OcrResult(blocks: [], imageSize: Size.zero).isEmpty, isTrue);
    });
  });
}
