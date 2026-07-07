import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/ocr_import/data/engines/tesseract_ocr_engine.dart';

const sampleTsv =
    'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
    '1\t1\t0\t0\t0\t0\t0\t0\t1000\t1400\t-1\t\n'
    '4\t1\t1\t1\t1\t0\t10\t20\t100\t14\t-1\t\n'
    '5\t1\t1\t1\t1\t1\t10\t20\t50\t14\t91\tDEPTH\n'
    '5\t1\t1\t1\t1\t2\t70\t20\t40\t14\t88\t69\n';

void main() {
  test('parses tesseract TSV into line-level blocks', () async {
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async => ProcessResult(0, 0, sampleTsv, ''),
    );
    final result = await engine.recognize(Uint8List.fromList([1, 2, 3]));
    expect(result.blocks.single.text, 'DEPTH 69');
    expect(
      result.blocks.single.boundingBox,
      const Rect.fromLTWH(10, 20, 100, 14),
    );
    expect(result.blocks.single.confidence, closeTo(0.895, 0.001));
    expect(result.imageSize, const Size(1000, 1400));
  });

  test('isAvailable false when binary missing', () async {
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async => ProcessResult(0, 1, '', 'not found'),
    );
    expect(await engine.isAvailable, isFalse);
  });

  test('isAvailable true when which succeeds', () async {
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async =>
          ProcessResult(0, 0, '/usr/bin/tesseract', ''),
    );
    expect(await engine.isAvailable, isTrue);
  });

  test('nonzero exit yields empty result', () async {
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async => ProcessResult(0, 1, '', 'boom'),
    );
    final result = await engine.recognize(Uint8List.fromList([1]));
    expect(result.isEmpty, isTrue);
  });

  test('ProcessException during recognize yields empty result', () async {
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async =>
          throw const ProcessException('tesseract', []),
    );
    final result = await engine.recognize(Uint8List.fromList([1]));
    expect(result.isEmpty, isTrue);
  });

  test('ProcessException during which yields unavailable', () async {
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async =>
          throw const ProcessException('which', []),
    );
    expect(await engine.isAvailable, isFalse);
  });

  test('words without confidence produce a null line confidence', () async {
    const tsv =
        'level\tpage_num\tblock_num\tpar_num\tline_num\tword_num\tleft\ttop\twidth\theight\tconf\ttext\n'
        '1\t1\t0\t0\t0\t0\t0\t0\t1000\t1400\t-1\t\n'
        '4\t1\t1\t1\t1\t0\t10\t20\t100\t14\t-1\t\n'
        '5\t1\t1\t1\t1\t1\t10\t20\t50\t14\t-1\tDEPTH\n';
    final engine = TesseractOcrEngine(
      runProcess: (cmd, args) async => ProcessResult(0, 0, tsv, ''),
    );
    final result = await engine.recognize(Uint8List.fromList([1]));
    expect(result.blocks.single.confidence, isNull);
  });

  test('default runner executes a real process for isAvailable', () async {
    // Exercises the Process.run default; the result depends on whether
    // tesseract is installed, so only the type is asserted.
    expect(await TesseractOcrEngine().isAvailable, isA<bool>());
  });
}
