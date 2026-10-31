import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';

/// Mean depth over elapsed time, not over samples (#3891).
void main() {
  final service = ProfileAnalysisService();

  for (final mode in [DiveMode.gauge, DiveMode.oc]) {
    group('mean depth on a ${mode.name} dive', () {
      test('weights the averages by elapsed time', () {
        final analysis = service.analyze(
          diveId: 'd',
          timestamps: const [0, 60, 120, 600],
          depths: const [10, 10, 30, 30],
          diveMode: mode,
        );

        // (60 * 10 + 60 * 20 + 480 * 30) / 600
        expect(analysis.averageDepth, closeTo(27, 1e-9));
        expect(analysis.meanDepthCurve, hasLength(4));
        expect(analysis.meanDepthCurve![0], closeTo(10, 1e-9));
        expect(analysis.meanDepthCurve![1], closeTo(10, 1e-9));
        expect(analysis.meanDepthCurve![2], closeTo(15, 1e-9));
        expect(analysis.meanDepthCurve![3], closeTo(27, 1e-9));
      });

      test('another sample on a flat segment changes neither mean', () {
        final analysis = service.analyze(
          diveId: 'd',
          timestamps: const [0, 30, 60, 120, 600],
          depths: const [10, 10, 10, 30, 30],
          diveMode: mode,
        );

        expect(analysis.averageDepth, closeTo(27, 1e-9));
        expect(analysis.meanDepthCurve!.last, closeTo(27, 1e-9));
      });

      test('a single sample is its own mean', () {
        final analysis = service.analyze(
          diveId: 'd',
          timestamps: const [0],
          depths: const [12],
          diveMode: mode,
        );

        expect(analysis.averageDepth, closeTo(12, 1e-9));
        expect(analysis.meanDepthCurve, [closeTo(12, 1e-9)]);
      });
    });
  }

  group('SAC over uneven samples', () {
    test('a 5-minute segment normalizes by its time-weighted depth', () {
      final analysis = service.analyze(
        diveId: 'd',
        timestamps: const [0, 60, 120, 300],
        depths: const [10, 10, 30, 30],
        pressures: const [200, 190, 180, 150],
      );

      final segment = analysis.sacSegments!.single;
      // (60 * 10 + 60 * 20 + 180 * 30) / 300
      expect(segment.avgDepth, closeTo(24, 1e-9));
      // 50 bar in 5 minutes at 3.4 bar ambient. A sample average of 20 m
      // would say 3.33.
      expect(segment.sacRate, closeTo(10 / 3.4, 1e-9));
    });

    test('the rolling window normalizes by its time-weighted depth', () {
      final analysis = service.analyze(
        diveId: 'd',
        timestamps: const [0, 5, 30, 600],
        depths: const [10, 10, 20, 20],
        pressures: const [200, 199, 196, 100],
      );

      // The window around t=0 reaches t=30: (5 * 10 + 25 * 15) / 30 m,
      // against 13.33 m from a sample average, and 4 bar in half a minute.
      const depth = (5 * 10 + 25 * 15) / 30;
      expect(
        analysis.smoothedSacCurve!.first,
        closeTo(8 / (1 + depth / 10), 1e-9),
      );
    });
  });
}
