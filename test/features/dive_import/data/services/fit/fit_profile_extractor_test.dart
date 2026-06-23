import 'package:fit_tool/fit_tool.dart';
import 'package:flutter_test/flutter_test.dart';
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
      ..cnsLoad = 15;
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
  });

  test('keeps the record timestamp as Unix ms for later merge alignment', () {
    final r = RecordMessage()
      ..timestamp = start.millisecondsSinceEpoch
      ..depth = 5.0;
    final s = FitProfileExtractor.extract([r]).single;
    expect(s.timestampMs, start.millisecondsSinceEpoch);
  });
}
