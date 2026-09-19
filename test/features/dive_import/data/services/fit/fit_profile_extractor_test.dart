import 'dart:io';

import 'package:fit_tool/fit_tool.dart';
// ignore: implementation_imports
import 'package:fit_tool/src/utils/logger.dart' as fit_log;
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart' show Level, Logger;
import 'package:submersion/features/dive_import/data/services/fit/fit_profile_extractor.dart';

void main() {
  final start = DateTime.utc(2025, 10, 13, 8, 51, 10);

  test('extracts depth + recorded deco fields, skips depthless records', () {
    final r1 = RecordMessage()
      ..timestamp = start.millisecondsSinceEpoch
      ..depth = 24.257
      ..temperature = 23
      ..nextStopDepth = 6.0
      ..timeToSurface = 480
      ..ndlTime = 0
      ..cnsLoad = 15
      ..n2Load = 42;
    final r2 = RecordMessage()
      ..timestamp = start
          .add(const Duration(seconds: 1))
          .millisecondsSinceEpoch;

    final samples = FitProfileExtractor.extract([r1, r2]);

    expect(samples, hasLength(1));
    final s = samples.single;
    expect(s.depth, closeTo(24.257, 1e-6));
    expect(s.temperature, 23);
    expect(s.ceiling, 6.0);
    expect(s.ttsSeconds, 480);
    expect(s.ndlSeconds, 0);
    expect(s.cns, 15);
    expect(s.n2Load, 42);
  });

  test('leaves n2Load null when the record does not carry it', () {
    final r = RecordMessage()
      ..timestamp = start.millisecondsSinceEpoch
      ..depth = 5.0
      ..cnsLoad = 3;
    final s = FitProfileExtractor.extract([r]).single;
    expect(s.n2Load, isNull);
    expect(s.cns, 3);
  });

  test('treats an out-of-range n2Load as absent', () {
    final r = RecordMessage()
      ..timestamp = start.millisecondsSinceEpoch
      ..depth = 5.0
      ..n2Load = 1001;
    final s = FitProfileExtractor.extract([r]).single;
    expect(s.n2Load, isNull);
  });

  test('reads the recorded N2 loading from a real Descent file', () {
    // Silence fit_tool's warnings about fields its bundled profile lacks.
    fit_log.logger = Logger(level: Level.error);
    final bytes = File(
      'test/dives/005_oc-trimix-two-deco-gases.fit',
    ).readAsBytesSync();
    final records = FitFile.fromBytes(
      bytes,
    ).records.map((r) => r.message).whereType<RecordMessage>().toList();

    final samples = FitProfileExtractor.extract(records);
    final loads = samples.map((s) => s.n2Load).whereType<int>().toList();

    // Only the very first record lacks n2_load. The loading peaks well above
    // 100 mid-dive (a trimix deco dive) and the final sample matches the
    // dive_summary end_n2 of 86.
    expect(samples, hasLength(3921));
    expect(loads, hasLength(3920));
    expect(samples.first.n2Load, isNull);
    expect(loads.last, 86);
    expect(loads.reduce((a, b) => a > b ? a : b), 191);
  });

  test('keeps the record timestamp as Unix ms for later merge alignment', () {
    final r = RecordMessage()
      ..timestamp = start.millisecondsSinceEpoch
      ..depth = 5.0;
    final s = FitProfileExtractor.extract([r]).single;
    expect(s.timestampMs, start.millisecondsSinceEpoch);
  });
}
