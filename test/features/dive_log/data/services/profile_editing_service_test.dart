import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';

void main() {
  late ProfileEditingService service;

  setUp(() {
    service = ProfileEditingService();
  });

  group('detectOutliers', () {
    test('returns empty for clean profile', () {
      // Smooth descent: 0m, 3m, 6m, 9m, 12m, 15m, 18m (steady 1m/s)
      final profile = List.generate(
        7,
        (i) => DiveProfilePoint(timestamp: i * 3, depth: i * 3.0),
      );
      final outliers = service.detectOutliers(profile);
      expect(outliers, isEmpty);
    });

    test('detects sudden depth spike', () {
      // Smooth descent with one 20m spike at index 3
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 3.0),
        const DiveProfilePoint(timestamp: 8, depth: 6.0),
        const DiveProfilePoint(timestamp: 12, depth: 25.0), // spike!
        const DiveProfilePoint(timestamp: 16, depth: 9.0),
        const DiveProfilePoint(timestamp: 20, depth: 12.0),
        const DiveProfilePoint(timestamp: 24, depth: 15.0),
        const DiveProfilePoint(timestamp: 28, depth: 18.0),
        const DiveProfilePoint(timestamp: 32, depth: 18.0),
        const DiveProfilePoint(timestamp: 36, depth: 18.0),
        const DiveProfilePoint(timestamp: 40, depth: 18.0),
        const DiveProfilePoint(timestamp: 44, depth: 18.0),
      ];
      final outliers = service.detectOutliers(profile);
      expect(outliers, isNotEmpty);
      expect(outliers.any((o) => o.index == 3), isTrue);
    });

    test('does not flag normal fast descent', () {
      // Fast but consistent descent: ~2m per sample
      final profile = List.generate(
        16,
        (i) => DiveProfilePoint(timestamp: i * 2, depth: i * 2.0),
      );
      final outliers = service.detectOutliers(profile);
      expect(outliers, isEmpty);
    });

    test('flags physical impossibility (>3m/s)', () {
      // Normal profile with one physically impossible jump
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 1, depth: 10.0),
        const DiveProfilePoint(timestamp: 2, depth: 10.0),
        const DiveProfilePoint(timestamp: 3, depth: 10.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 5, depth: 10.0),
        const DiveProfilePoint(timestamp: 6, depth: 10.0),
        const DiveProfilePoint(timestamp: 7, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 10.0),
        const DiveProfilePoint(timestamp: 9, depth: 10.0),
        const DiveProfilePoint(timestamp: 10, depth: 10.0),
        const DiveProfilePoint(timestamp: 11, depth: 15.0), // 5m in 1s = 5m/s
        const DiveProfilePoint(timestamp: 12, depth: 10.0),
      ];
      final outliers = service.detectOutliers(profile);
      expect(outliers.any((o) => o.isPhysicallyImpossible), isTrue);
    });

    test('returns empty for profile with fewer than 3 points', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
      ];
      final outliers = service.detectOutliers(profile);
      expect(outliers, isEmpty);
    });

    test('returns empty for empty profile', () {
      final outliers = service.detectOutliers([]);
      expect(outliers, isEmpty);
    });
  });

  group('smoothProfile', () {
    test('preserves first and last points', () {
      final profile = List.generate(
        10,
        (i) => DiveProfilePoint(
          timestamp: i * 4,
          depth: 10.0 + (i % 2 == 0 ? 0.5 : -0.5),
        ),
      );
      final smoothed = service.smoothProfile(profile, windowSize: 3);
      expect(smoothed.first.depth, profile.first.depth);
      expect(smoothed.last.depth, profile.last.depth);
      expect(smoothed.first.timestamp, profile.first.timestamp);
      expect(smoothed.last.timestamp, profile.last.timestamp);
    });

    test('reduces noise (stddev decreases)', () {
      // Noisy profile around 15m
      final rng = math.Random(42);
      final profile = List.generate(
        50,
        (i) => DiveProfilePoint(
          timestamp: i * 4,
          depth: 15.0 + (rng.nextDouble() - 0.5) * 4.0, // +/- 2m noise
        ),
      );

      double stddev(List<DiveProfilePoint> p) {
        final mean = p.fold<double>(0.0, (s, pt) => s + pt.depth) / p.length;
        final variance =
            p.fold<double>(
              0.0,
              (s, pt) => s + (pt.depth - mean) * (pt.depth - mean),
            ) /
            p.length;
        return math.sqrt(variance);
      }

      final smoothed = service.smoothProfile(profile, windowSize: 5);
      expect(stddev(smoothed), lessThan(stddev(profile)));
    });

    test('preserves max depth within tolerance', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 5.0),
        const DiveProfilePoint(timestamp: 8, depth: 10.0),
        const DiveProfilePoint(timestamp: 12, depth: 15.0),
        const DiveProfilePoint(timestamp: 16, depth: 20.0),
        const DiveProfilePoint(timestamp: 20, depth: 20.0),
        const DiveProfilePoint(timestamp: 24, depth: 15.0),
        const DiveProfilePoint(timestamp: 28, depth: 10.0),
        const DiveProfilePoint(timestamp: 32, depth: 5.0),
        const DiveProfilePoint(timestamp: 36, depth: 0.0),
      ];
      final smoothed = service.smoothProfile(profile, windowSize: 3);
      final maxSmoothed = smoothed.map((p) => p.depth).reduce(math.max);
      expect(maxSmoothed, closeTo(20.0, 3.0)); // within 3m tolerance
    });

    test('returns same profile for empty or single point', () {
      expect(service.smoothProfile([]), isEmpty);
      final single = [const DiveProfilePoint(timestamp: 0, depth: 10.0)];
      final result = service.smoothProfile(single);
      expect(result.length, 1);
      expect(result.first.depth, 10.0);
    });

    test('clamps window to profile length', () {
      final profile = List.generate(
        3,
        (i) => DiveProfilePoint(timestamp: i * 4, depth: 10.0 + i),
      );
      // windowSize 7 is larger than profile length 3 -- should not crash
      final smoothed = service.smoothProfile(profile, windowSize: 7);
      expect(smoothed.length, 3);
    });
  });

  group('removeOutliers', () {
    test('interpolates removed points', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 30.0), // outlier
        const DiveProfilePoint(timestamp: 12, depth: 10.0),
        const DiveProfilePoint(timestamp: 16, depth: 10.0),
      ];
      final outliers = [
        const OutlierResult(
          index: 2,
          timestamp: 8,
          depth: 30.0,
          depthDelta: 20.0,
          zScore: 5.0,
        ),
      ];
      final cleaned = service.removeOutliers(profile, outliers);
      expect(cleaned.length, profile.length);
      // Interpolated: midpoint between 10.0 and 10.0 = 10.0
      expect(cleaned[2].depth, closeTo(10.0, 0.1));
      expect(cleaned[2].timestamp, 8); // timestamp preserved
    });

    test('handles outlier at first point', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 50.0), // outlier
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 10.0),
      ];
      final outliers = [
        const OutlierResult(
          index: 0,
          timestamp: 0,
          depth: 50.0,
          depthDelta: 50.0,
          zScore: 5.0,
        ),
      ];
      final cleaned = service.removeOutliers(profile, outliers);
      // First point has no left neighbor -- use right neighbor's depth
      expect(cleaned[0].depth, 10.0);
    });

    test('returns original when no outliers provided', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 4, depth: 15.0),
      ];
      final cleaned = service.removeOutliers(profile, []);
      expect(cleaned, profile);
    });
  });
}
