import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:submersion/features/ocr_import/domain/models/ocr_result.dart';
import 'package:submersion/features/ocr_import/domain/services/ocr_engine.dart';

typedef RunProcess = Future<ProcessResult> Function(String, List<String>);

/// Linux engine: shells out to the system `tesseract` binary in TSV mode.
/// Print-quality pages only; handwriting support is poor by nature.
class TesseractOcrEngine implements OcrEngine {
  final RunProcess _run;

  TesseractOcrEngine({RunProcess? runProcess})
    : _run = runProcess ?? _defaultRun;

  static Future<ProcessResult> _defaultRun(String cmd, List<String> args) =>
      Process.run(cmd, args);

  @override
  Future<bool> get isAvailable async {
    try {
      final result = await _run('which', ['tesseract']);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    }
  }

  @override
  Future<OcrResult> recognize(Uint8List imageBytes) async {
    Directory? tmp;
    try {
      tmp = await Directory.systemTemp.createTemp('submersion_ocr');
      final file = File('${tmp.path}/page.png');
      await file.writeAsBytes(imageBytes);
      final result = await _run('tesseract', [file.path, 'stdout', 'tsv']);
      if (result.exitCode != 0) {
        return const OcrResult(blocks: [], imageSize: Size.zero);
      }
      return _parseTsv(result.stdout as String);
    } on ProcessException {
      return const OcrResult(blocks: [], imageSize: Size.zero);
    } finally {
      await tmp?.delete(recursive: true);
    }
  }

  OcrResult _parseTsv(String tsv) {
    var imageSize = Size.zero;
    final lineRects = <String, Rect>{};
    final lineWords = <String, List<String>>{};
    final lineConfs = <String, List<double>>{};

    for (final row in tsv.split('\n').skip(1)) {
      final cols = row.split('\t');
      if (cols.length < 12) continue;
      final level = int.tryParse(cols[0]);
      if (level == null) continue;
      final rect = Rect.fromLTWH(
        double.tryParse(cols[6]) ?? 0,
        double.tryParse(cols[7]) ?? 0,
        double.tryParse(cols[8]) ?? 0,
        double.tryParse(cols[9]) ?? 0,
      );
      final key = '${cols[2]}:${cols[3]}:${cols[4]}';
      if (level == 1) {
        imageSize = Size(rect.width, rect.height);
      } else if (level == 4) {
        lineRects[key] = rect;
      } else if (level == 5) {
        final text = cols[11].trim();
        if (text.isEmpty) continue;
        lineWords.putIfAbsent(key, () => []).add(text);
        final conf = double.tryParse(cols[10]) ?? -1;
        if (conf >= 0) lineConfs.putIfAbsent(key, () => []).add(conf);
      }
    }

    final blocks = <OcrTextBlock>[
      for (final entry in lineWords.entries)
        if (lineRects.containsKey(entry.key))
          OcrTextBlock(
            text: entry.value.join(' '),
            boundingBox: lineRects[entry.key]!,
            confidence: lineConfs[entry.key] == null
                ? null
                : lineConfs[entry.key]!.reduce((a, b) => a + b) /
                      lineConfs[entry.key]!.length /
                      100,
          ),
    ];
    return OcrResult(blocks: blocks, imageSize: imageSize);
  }
}
