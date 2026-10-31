import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/range_profile_stats.dart';

DiveProfilePoint _sample(int timestamp, double depth) =>
    DiveProfilePoint(timestamp: timestamp, depth: depth);

/// The issue's profile: flat at 10 m, sampled every 30 s from t=0.
final _flat = [for (var t = 0; t <= 120; t += 30) _sample(t, 10)];

void main() {
  group('rangeProfileStats (#3890)', () {
    test('elapsed is the selection, not its first to last interior sample', () {
      final stats = rangeProfileStats(
        profile: _flat,
        startTimestamp: 15,
        endTimestamp: 105,
      );

      expect(stats.elapsedSeconds, 90);
      expect(stats.avgDepth, 10);
    });

    test('a selection between two samples reads the line through them', () {
      final stats = rangeProfileStats(
        profile: _flat,
        startTimestamp: 15,
        endTimestamp: 25,
      );

      expect(stats.elapsedSeconds, 10);
      expect(stats.minDepth, 10);
      expect(stats.maxDepth, 10);
      expect(stats.avgDepth, 10);
      expect(stats.depthDelta, 0);
    });

    test('interpolates the selection edges on the plotted line', () {
      // 0 m at 0:00 to 30 m at 1:00: 1:00 is outside the selection, so its
      // 30 m must not reach Max Depth, and 0:00 must not reach Min Depth.
      final stats = rangeProfileStats(
        profile: [_sample(0, 0), _sample(60, 30)],
        startTimestamp: 10,
        endTimestamp: 40,
      );

      expect(stats.minDepth, closeTo(5, 1e-9));
      expect(stats.maxDepth, closeTo(20, 1e-9));
      expect(stats.depthDelta, closeTo(15, 1e-9));
      expect(stats.avgDepth, closeTo(12.5, 1e-9));
    });

    test('the part of a segment inside the selection keeps its rate', () {
      final stats = rangeProfileStats(
        profile: [_sample(0, 0), _sample(60, 30), _sample(120, 15)],
        startTimestamp: 30,
        endTimestamp: 90,
      );

      // 30 m/min down until 1:00, then 15 m/min up, both clipped by the edges.
      expect(stats.maxDescentRate, closeTo(30, 1e-9));
      expect(stats.maxAscentRate, closeTo(15, 1e-9));
      // 15 m at 0:30 to 22.5 m at 1:30.
      expect(stats.avgVerticalSpeed, closeTo(7.5, 1e-9));
    });

    test('a selection between two samples has a rate', () {
      final stats = rangeProfileStats(
        profile: [_sample(0, 0), _sample(60, 30)],
        startTimestamp: 10,
        endTimestamp: 20,
      );

      expect(stats.maxDescentRate, closeTo(30, 1e-9));
      expect(stats.maxAscentRate, 0);
      expect(stats.avgVerticalSpeed, closeTo(30, 1e-9));
    });

    test('average depth weights each depth by the time spent there', () {
      // 45 s flat at 10 m, then 5 s down to 20 m. A mean of the three samples
      // would count that short descent as much as the long flat stretch.
      final stats = rangeProfileStats(
        profile: [_sample(0, 10), _sample(45, 10), _sample(50, 20)],
        startTimestamp: 0,
        endTimestamp: 50,
      );

      // (45 * 10 + 5 * 15) / 50.
      expect(stats.avgDepth, closeTo(10.5, 1e-9));
    });

    test('takes a selection edge on a sample as that sample', () {
      final stats = rangeProfileStats(
        profile: [_sample(0, 10), _sample(30, 20), _sample(60, 40)],
        startTimestamp: 30,
        endTimestamp: 60,
      );

      expect(stats.minDepth, 20);
      expect(stats.maxDepth, 40);
      expect(stats.depthDelta, 20);
    });

    group('the surface lead-in', () {
      final descent = [_sample(10, 5), _sample(20, 10), _sample(30, 15)];

      test('is part of the plotted line, so it counts', () {
        final stats = rangeProfileStats(
          profile: descent,
          startTimestamp: 0,
          endTimestamp: 20,
        );

        expect(stats.elapsedSeconds, 20);
        expect(stats.minDepth, 0);
        expect(stats.maxDepth, 10);
        expect(stats.depthDelta, 10);
      });

      test('reads a selection before the first sample', () {
        final stats = rangeProfileStats(
          profile: descent,
          startTimestamp: 2,
          endTimestamp: 6,
        );

        expect(stats.minDepth, closeTo(1, 1e-9));
        expect(stats.maxDepth, closeTo(3, 1e-9));
      });
    });

    group('a selection the plotted line does not fully reach', () {
      // Trimmed: the first sample is too far in to draw a lead-in, so the
      // chart has no line before 5:00.
      final trimmed = [_sample(300, 10), _sample(360, 16), _sample(420, 16)];

      test('describes the depth of the part it does reach', () {
        final stats = rangeProfileStats(
          profile: trimmed,
          startTimestamp: 240,
          endTimestamp: 360,
        );

        // The selection stays two minutes, but no surface is invented.
        expect(stats.elapsedSeconds, 120);
        expect(stats.minDepth, 10);
        expect(stats.maxDepth, 16);
        expect(stats.avgDepth, closeTo(13, 1e-9));
        expect(stats.depthDelta, 6);
        // 6 m over the one minute drawn, not the two selected.
        expect(stats.avgVerticalSpeed, closeTo(6, 1e-9));
      });

      test('reports nothing for a selection off the line altogether', () {
        final stats = rangeProfileStats(
          profile: trimmed,
          startTimestamp: 100,
          endTimestamp: 200,
        );

        expect(stats.elapsedSeconds, 100);
        expect(stats.depthDelta, isNull);
        expect(stats.minDepth, isNull);
        expect(stats.maxDepth, isNull);
        expect(stats.avgDepth, isNull);
        expect(stats.avgVerticalSpeed, isNull);
        expect(stats.maxDescentRate, isNull);
        expect(stats.maxAscentRate, isNull);
      });

      test('a single touching sample has a depth but no change', () {
        final stats = rangeProfileStats(
          profile: trimmed,
          startTimestamp: 200,
          endTimestamp: 300,
        );

        expect(stats.minDepth, 10);
        expect(stats.maxDepth, 10);
        expect(stats.avgDepth, 10);
        expect(stats.depthDelta, isNull);
        expect(stats.avgVerticalSpeed, isNull);
        expect(stats.maxDescentRate, isNull);
        expect(stats.maxAscentRate, isNull);
      });

      test('an empty profile keeps the elapsed time and nothing else', () {
        final stats = rangeProfileStats(
          profile: const [],
          startTimestamp: 15,
          endTimestamp: 25,
        );

        expect(stats.elapsedSeconds, 10);
        expect(stats.minDepth, isNull);
        expect(stats.avgDepth, isNull);
      });
    });

    group('temperature and heart rate', () {
      test('stay the readings recorded inside the selection', () {
        final stats = rangeProfileStats(
          profile: const [
            DiveProfilePoint(
              timestamp: 0,
              depth: 10,
              temperature: 30,
              heartRate: 150,
            ),
            DiveProfilePoint(
              timestamp: 30,
              depth: 10,
              temperature: 20,
              heartRate: 90,
            ),
            DiveProfilePoint(
              timestamp: 60,
              depth: 10,
              temperature: 22,
              heartRate: 100,
            ),
            DiveProfilePoint(
              timestamp: 90,
              depth: 10,
              temperature: 10,
              heartRate: 60,
            ),
          ],
          startTimestamp: 15,
          endTimestamp: 75,
        );

        expect(stats.minTemp, 20);
        expect(stats.maxTemp, 22);
        expect(stats.minHR, 90);
        expect(stats.maxHR, 100);
      });

      test('a selection holding one reading still reports it', () {
        final stats = rangeProfileStats(
          profile: const [
            DiveProfilePoint(timestamp: 0, depth: 10),
            DiveProfilePoint(
              timestamp: 30,
              depth: 10,
              temperature: 20,
              heartRate: 90,
            ),
            DiveProfilePoint(timestamp: 60, depth: 10),
          ],
          startTimestamp: 15,
          endTimestamp: 45,
        );

        expect(stats.minTemp, 20);
        expect(stats.maxHR, 90);
      });

      test('a selection holding none reports none, not zero', () {
        final stats = rangeProfileStats(
          profile: _flat,
          startTimestamp: 15,
          endTimestamp: 25,
        );

        expect(stats.minTemp, isNull);
        expect(stats.maxTemp, isNull);
        expect(stats.minHR, isNull);
        expect(stats.maxHR, isNull);
      });
    });
  });
}
