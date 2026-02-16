import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';

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

  group('shiftSegmentDepth', () {
    test('shifts only points in range', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 10.0),
        const DiveProfilePoint(timestamp: 12, depth: 10.0),
        const DiveProfilePoint(timestamp: 16, depth: 10.0),
      ];
      final shifted = service.shiftSegmentDepth(
        profile,
        startTimestamp: 4,
        endTimestamp: 12,
        depthDelta: 5.0,
      );
      expect(shifted[0].depth, 10.0); // before range
      expect(shifted[1].depth, 15.0); // in range
      expect(shifted[2].depth, 15.0); // in range
      expect(shifted[3].depth, 15.0); // in range
      expect(shifted[4].depth, 10.0); // after range
    });

    test('clamps depth to zero (no negative depths)', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 2.0),
        const DiveProfilePoint(timestamp: 4, depth: 2.0),
      ];
      final shifted = service.shiftSegmentDepth(
        profile,
        startTimestamp: 0,
        endTimestamp: 4,
        depthDelta: -5.0,
      );
      expect(shifted[0].depth, 0.0);
      expect(shifted[1].depth, 0.0);
    });
  });

  group('shiftSegmentTime', () {
    test('shifts timestamps in range', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 10, depth: 15.0),
        const DiveProfilePoint(timestamp: 20, depth: 15.0),
        const DiveProfilePoint(timestamp: 30, depth: 10.0),
      ];
      final shifted = service.shiftSegmentTime(
        profile,
        startTimestamp: 10,
        endTimestamp: 20,
        timeDelta: 5,
      );
      expect(shifted![0].timestamp, 0);
      expect(shifted[1].timestamp, 15);
      expect(shifted[2].timestamp, 25);
      expect(shifted[3].timestamp, 30);
    });

    test('returns null when shift causes overlap', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 10.0),
        const DiveProfilePoint(timestamp: 10, depth: 15.0),
        const DiveProfilePoint(timestamp: 20, depth: 10.0),
      ];
      // Shifting middle point by +15 would put it at 25 > next point 20
      final result = service.shiftSegmentTime(
        profile,
        startTimestamp: 10,
        endTimestamp: 10,
        timeDelta: 15,
      );
      expect(result, isNull);
    });
  });

  group('deleteSegment', () {
    test('removes points in range with interpolation', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 20.0),
        const DiveProfilePoint(timestamp: 12, depth: 10.0),
        const DiveProfilePoint(timestamp: 16, depth: 0.0),
      ];
      final result = service.deleteSegment(
        profile,
        startTimestamp: 4,
        endTimestamp: 12,
        interpolateGap: true,
      );
      // Should have: point at 0, interpolated bridge, point at 16
      expect(result.first.depth, 0.0);
      expect(result.last.depth, 0.0);
      expect(result.length, lessThan(profile.length));
    });

    test('removes points without interpolation', () {
      final profile = [
        const DiveProfilePoint(timestamp: 0, depth: 0.0),
        const DiveProfilePoint(timestamp: 4, depth: 10.0),
        const DiveProfilePoint(timestamp: 8, depth: 20.0),
        const DiveProfilePoint(timestamp: 12, depth: 10.0),
        const DiveProfilePoint(timestamp: 16, depth: 0.0),
      ];
      final result = service.deleteSegment(
        profile,
        startTimestamp: 4,
        endTimestamp: 12,
      );
      expect(result.length, 2); // only first and last remain
      expect(result[0].timestamp, 0);
      expect(result[1].timestamp, 16);
    });
  });

  group('interpolateWaypoints', () {
    test('generates points between two waypoints', () {
      final waypoints = [
        const ProfileWaypoint(timestamp: 0, depth: 0.0),
        const ProfileWaypoint(timestamp: 20, depth: 20.0),
      ];
      final profile = service.interpolateWaypoints(
        waypoints,
        intervalSeconds: 4,
      );
      // Expect points at 0, 4, 8, 12, 16, 20 = 6 points
      expect(profile.length, 6);
      expect(profile.first.depth, 0.0);
      expect(profile.last.depth, 20.0);
      // Midpoint should be interpolated
      expect(profile[2].depth, closeTo(8.0, 0.1)); // at t=8, depth=8
    });

    test('respects interval spacing', () {
      final waypoints = [
        const ProfileWaypoint(timestamp: 0, depth: 0.0),
        const ProfileWaypoint(timestamp: 100, depth: 30.0),
      ];
      final profile = service.interpolateWaypoints(
        waypoints,
        intervalSeconds: 10,
      );
      // Points at 0, 10, 20, ..., 100 = 11 points
      expect(profile.length, 11);
      for (int i = 0; i < profile.length; i++) {
        expect(profile[i].timestamp, i * 10);
      }
    });

    test('handles multiple waypoints', () {
      final waypoints = [
        const ProfileWaypoint(timestamp: 0, depth: 0.0),
        const ProfileWaypoint(timestamp: 60, depth: 20.0),
        const ProfileWaypoint(timestamp: 180, depth: 20.0), // flat bottom
        const ProfileWaypoint(timestamp: 240, depth: 5.0), // ascent
        const ProfileWaypoint(timestamp: 300, depth: 0.0), // surface
      ];
      final profile = service.interpolateWaypoints(
        waypoints,
        intervalSeconds: 4,
      );
      expect(profile.first.depth, 0.0);
      expect(profile.last.depth, 0.0);
      expect(profile.last.timestamp, 300);
      // All depths should be >= 0
      for (final point in profile) {
        expect(point.depth, greaterThanOrEqualTo(0.0));
      }
    });

    test('returns empty for empty waypoints', () {
      expect(service.interpolateWaypoints([]), isEmpty);
    });

    test('returns single point for single waypoint', () {
      final waypoints = [const ProfileWaypoint(timestamp: 0, depth: 10.0)];
      final profile = service.interpolateWaypoints(waypoints);
      expect(profile.length, 1);
      expect(profile.first.depth, 10.0);
    });
  });
}
