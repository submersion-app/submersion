# Profile Editing Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Add non-destructive profile editing to Submersion: outlier detection/removal, smoothing, manual waypoint drawing, and range-based segment editing.

**Architecture:** Separate Profile Editor Page (`/dives/:diveId/edit-profile`) with a pure-Dart `ProfileEditingService` for algorithms, a simplified `ProfileEditorChart` for the editing UI, and `StateNotifier`-based session state. Edited profiles stored in existing `DiveProfiles` table using `computerId = 'user-edited'` and `isPrimary` toggling -- no schema changes.

**Tech Stack:** Flutter, fl_chart, Drift ORM, Riverpod (StateNotifierProvider), Equatable, go_router.

**Design doc:** `docs/plans/2026-02-16-profile-editing-design.md`

---

## Task 1: Domain Entities (OutlierResult, ProfileWaypoint)

Create the two new domain entities needed by the editing service.

**Files:**
- Create: `lib/features/dive_log/domain/entities/outlier_result.dart`
- Create: `lib/features/dive_log/domain/entities/profile_waypoint.dart`
- Test: `test/features/dive_log/domain/entities/outlier_result_test.dart`
- Test: `test/features/dive_log/domain/entities/profile_waypoint_test.dart`

**Step 1: Write OutlierResult entity**

```dart
import 'package:equatable/equatable.dart';

/// Result of outlier detection for a single profile point.
class OutlierResult extends Equatable {
  /// Index of the outlier point in the profile list
  final int index;

  /// Timestamp of the outlier point (seconds from dive start)
  final int timestamp;

  /// Depth of the outlier point (meters)
  final double depth;

  /// The depth delta that triggered the outlier flag
  final double depthDelta;

  /// Z-score of this point's delta relative to the local window
  final double zScore;

  /// Whether this was flagged by physical impossibility (>3m/s)
  final bool isPhysicallyImpossible;

  const OutlierResult({
    required this.index,
    required this.timestamp,
    required this.depth,
    required this.depthDelta,
    required this.zScore,
    this.isPhysicallyImpossible = false,
  });

  @override
  List<Object?> get props => [
    index,
    timestamp,
    depth,
    depthDelta,
    zScore,
    isPhysicallyImpossible,
  ];
}
```

**Step 2: Write ProfileWaypoint entity**

```dart
import 'package:equatable/equatable.dart';

/// A user-placed waypoint for manual profile drawing.
class ProfileWaypoint extends Equatable {
  /// Timestamp in seconds from dive start
  final int timestamp;

  /// Depth in meters
  final double depth;

  const ProfileWaypoint({
    required this.timestamp,
    required this.depth,
  });

  ProfileWaypoint copyWith({
    int? timestamp,
    double? depth,
  }) {
    return ProfileWaypoint(
      timestamp: timestamp ?? this.timestamp,
      depth: depth ?? this.depth,
    );
  }

  @override
  List<Object?> get props => [timestamp, depth];
}
```

**Step 3: Write tests for both entities**

Test Equatable props, copyWith behavior. Keep simple -- these are value objects.

```dart
// outlier_result_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';

void main() {
  group('OutlierResult', () {
    test('two OutlierResults with same values are equal', () {
      const a = OutlierResult(
        index: 5, timestamp: 60, depth: 15.0, depthDelta: 8.0, zScore: 4.5,
      );
      const b = OutlierResult(
        index: 5, timestamp: 60, depth: 15.0, depthDelta: 8.0, zScore: 4.5,
      );
      expect(a, equals(b));
    });

    test('isPhysicallyImpossible defaults to false', () {
      const r = OutlierResult(
        index: 0, timestamp: 0, depth: 0, depthDelta: 0, zScore: 0,
      );
      expect(r.isPhysicallyImpossible, isFalse);
    });
  });
}
```

```dart
// profile_waypoint_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';

void main() {
  group('ProfileWaypoint', () {
    test('copyWith creates new instance with updated fields', () {
      const original = ProfileWaypoint(timestamp: 0, depth: 10.0);
      final updated = original.copyWith(depth: 20.0);
      expect(updated.depth, 20.0);
      expect(updated.timestamp, 0);
      expect(original.depth, 10.0); // immutable
    });

    test('two waypoints with same values are equal', () {
      const a = ProfileWaypoint(timestamp: 60, depth: 18.0);
      const b = ProfileWaypoint(timestamp: 60, depth: 18.0);
      expect(a, equals(b));
    });
  });
}
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_log/domain/entities/outlier_result_test.dart test/features/dive_log/domain/entities/profile_waypoint_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/domain/entities/outlier_result.dart \
        lib/features/dive_log/domain/entities/profile_waypoint.dart \
        test/features/dive_log/domain/entities/outlier_result_test.dart \
        test/features/dive_log/domain/entities/profile_waypoint_test.dart
git commit -m "feat: add OutlierResult and ProfileWaypoint entities"
```

---

## Task 2: ProfileEditingService -- Outlier Detection

Build the outlier detection algorithm (z-score on depth deltas).

**Files:**
- Create: `lib/features/dive_log/data/services/profile_editing_service.dart`
- Create: `test/features/dive_log/data/services/profile_editing_service_test.dart`

**Context:** `DiveProfilePoint` is defined in `lib/features/dive_log/domain/entities/dive.dart:589-632`. It has `timestamp` (int, seconds), `depth` (double, meters), and `copyWith()`.

**Step 1: Write failing tests for detectOutliers**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';

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
      // Fast but consistent descent: 2m/s for 30 seconds
      final profile = List.generate(
        16,
        (i) => DiveProfilePoint(timestamp: i * 2, depth: i * 2.0 * 1.0),
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
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: FAIL (class not found)

**Step 3: Implement detectOutliers**

Create `lib/features/dive_log/data/services/profile_editing_service.dart`:

```dart
import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';

/// Service for editing dive profiles.
///
/// Pure Dart -- no Flutter dependencies. All methods are stateless
/// and return new lists (never mutate input).
class ProfileEditingService {
  /// Detect outlier points in a dive profile using z-score on depth deltas.
  ///
  /// For each point, computes the depth delta from the previous point and
  /// compares it to the local window's mean and standard deviation. Points
  /// with deltas exceeding [zScoreThreshold] standard deviations are flagged.
  ///
  /// Additionally, any depth change exceeding [maxRateMetersPerSecond] is
  /// flagged as physically impossible regardless of z-score.
  List<OutlierResult> detectOutliers(
    List<DiveProfilePoint> profile, {
    int windowSize = 10,
    double zScoreThreshold = 3.0,
    double maxRateMetersPerSecond = 3.0,
  }) {
    if (profile.length < 3) return [];

    final results = <OutlierResult>[];

    // Calculate depth deltas
    final deltas = <double>[];
    for (int i = 1; i < profile.length; i++) {
      deltas.add(profile[i].depth - profile[i - 1].depth);
    }

    final halfWindow = windowSize ~/ 2;

    for (int i = 0; i < deltas.length; i++) {
      final delta = deltas[i];
      final pointIndex = i + 1; // delta[i] corresponds to profile[i+1]

      // Physical impossibility check
      final timeDiff =
          profile[pointIndex].timestamp - profile[pointIndex - 1].timestamp;
      final isPhysicallyImpossible = timeDiff > 0 &&
          delta.abs() / timeDiff > maxRateMetersPerSecond;

      // Z-score check: compare delta to local window
      final windowStart = math.max(0, i - halfWindow);
      final windowEnd = math.min(deltas.length, i + halfWindow + 1);
      final windowDeltas = deltas.sublist(windowStart, windowEnd);

      final mean =
          windowDeltas.reduce((a, b) => a + b) / windowDeltas.length;
      final variance = windowDeltas.fold<double>(
            0.0,
            (sum, d) => sum + (d - mean) * (d - mean),
          ) /
          windowDeltas.length;
      final stddev = math.sqrt(variance);

      final zScore = stddev > 0 ? (delta - mean).abs() / stddev : 0.0;
      final isZScoreOutlier = zScore > zScoreThreshold;

      if (isPhysicallyImpossible || isZScoreOutlier) {
        results.add(OutlierResult(
          index: pointIndex,
          timestamp: profile[pointIndex].timestamp,
          depth: profile[pointIndex].depth,
          depthDelta: delta,
          zScore: zScore,
          isPhysicallyImpossible: isPhysicallyImpossible,
        ));
      }
    }

    return results;
  }
}
```

**Step 4: Run tests to verify they pass**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/profile_editing_service.dart \
        test/features/dive_log/data/services/profile_editing_service_test.dart
git commit -m "feat: add ProfileEditingService with outlier detection"
```

---

## Task 3: ProfileEditingService -- Smoothing & Outlier Removal

Add smoothing and outlier removal methods.

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_editing_service.dart`
- Modify: `test/features/dive_log/data/services/profile_editing_service_test.dart`

**Step 1: Write failing tests for smoothProfile and removeOutliers**

Add to the test file:

```dart
  group('smoothProfile', () {
    test('preserves first and last points', () {
      final profile = List.generate(
        10,
        (i) => DiveProfilePoint(timestamp: i * 4, depth: 10.0 + (i % 2 == 0 ? 0.5 : -0.5)),
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
        final variance = p.fold<double>(0.0, (s, pt) => s + (pt.depth - mean) * (pt.depth - mean)) / p.length;
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
          index: 2, timestamp: 8, depth: 30.0, depthDelta: 20.0, zScore: 5.0,
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
          index: 0, timestamp: 0, depth: 50.0, depthDelta: 50.0, zScore: 5.0,
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
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: FAIL (methods not found)

**Step 3: Implement smoothProfile and removeOutliers**

Add to `ProfileEditingService`:

```dart
  /// Smooth a dive profile using weighted moving average with triangular kernel.
  ///
  /// [windowSize] controls the smoothing radius (3=light, 5=medium, 7=heavy).
  /// First and last points are preserved unchanged.
  /// All non-depth fields (pressure, temperature, etc.) are preserved.
  List<DiveProfilePoint> smoothProfile(
    List<DiveProfilePoint> profile, {
    int windowSize = 5,
  }) {
    if (profile.length <= 2) return List.of(profile);

    final effectiveWindow = math.min(windowSize, profile.length);
    final halfWindow = effectiveWindow ~/ 2;

    // Build triangular weights: [1, 2, ..., center, ..., 2, 1]
    final weights = List.generate(
      effectiveWindow,
      (i) => (i < halfWindow ? i + 1 : effectiveWindow - i).toDouble(),
    );
    final weightSum = weights.reduce((a, b) => a + b);

    final result = <DiveProfilePoint>[];

    for (int i = 0; i < profile.length; i++) {
      // Preserve first and last points
      if (i == 0 || i == profile.length - 1) {
        result.add(profile[i]);
        continue;
      }

      // Calculate weighted average of depth within window
      double weightedDepth = 0;
      double usedWeightSum = 0;

      for (int w = 0; w < effectiveWindow; w++) {
        final sourceIdx = i - halfWindow + w;
        if (sourceIdx >= 0 && sourceIdx < profile.length) {
          weightedDepth += profile[sourceIdx].depth * weights[w];
          usedWeightSum += weights[w];
        }
      }

      final smoothedDepth =
          usedWeightSum > 0 ? weightedDepth / usedWeightSum : profile[i].depth;

      result.add(profile[i].copyWith(depth: smoothedDepth));
    }

    return result;
  }

  /// Remove outlier points by replacing them with linearly interpolated values.
  ///
  /// For each outlier, replaces its depth with a linear interpolation between
  /// its nearest non-outlier neighbors. All other fields are preserved.
  List<DiveProfilePoint> removeOutliers(
    List<DiveProfilePoint> profile,
    List<OutlierResult> outliers,
  ) {
    if (outliers.isEmpty) return profile;

    final outlierIndices = outliers.map((o) => o.index).toSet();
    final result = List<DiveProfilePoint>.from(profile);

    for (final outlier in outliers) {
      final idx = outlier.index;
      if (idx < 0 || idx >= profile.length) continue;

      // Find nearest non-outlier neighbors
      double? leftDepth;
      double? rightDepth;
      int? leftIdx;
      int? rightIdx;

      for (int j = idx - 1; j >= 0; j--) {
        if (!outlierIndices.contains(j)) {
          leftDepth = profile[j].depth;
          leftIdx = j;
          break;
        }
      }

      for (int j = idx + 1; j < profile.length; j++) {
        if (!outlierIndices.contains(j)) {
          rightDepth = profile[j].depth;
          rightIdx = j;
          break;
        }
      }

      // Interpolate
      double interpolatedDepth;
      if (leftDepth != null && rightDepth != null) {
        // Linear interpolation based on index position
        final ratio = (idx - leftIdx!) / (rightIdx! - leftIdx);
        interpolatedDepth = leftDepth + (rightDepth - leftDepth) * ratio;
      } else if (leftDepth != null) {
        interpolatedDepth = leftDepth;
      } else if (rightDepth != null) {
        interpolatedDepth = rightDepth;
      } else {
        continue; // All points are outliers -- skip
      }

      result[idx] = profile[idx].copyWith(depth: interpolatedDepth);
    }

    return result;
  }
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/profile_editing_service.dart \
        test/features/dive_log/data/services/profile_editing_service_test.dart
git commit -m "feat: add profile smoothing and outlier removal"
```

---

## Task 4: ProfileEditingService -- Range Operations

Add segment shift, delete, and smooth-segment methods.

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_editing_service.dart`
- Modify: `test/features/dive_log/data/services/profile_editing_service_test.dart`

**Step 1: Write failing tests**

```dart
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
      expect(shifted[0].timestamp, 0);
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
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: FAIL

**Step 3: Implement range operations**

Add to `ProfileEditingService`:

```dart
  /// Shift depth of all points within a timestamp range.
  ///
  /// Points outside the range are unchanged. Depths are clamped to >= 0.
  List<DiveProfilePoint> shiftSegmentDepth(
    List<DiveProfilePoint> profile, {
    required int startTimestamp,
    required int endTimestamp,
    required double depthDelta,
  }) {
    final start = math.min(startTimestamp, endTimestamp);
    final end = math.max(startTimestamp, endTimestamp);

    return profile.map((point) {
      if (point.timestamp >= start && point.timestamp <= end) {
        final newDepth = math.max(0.0, point.depth + depthDelta);
        return point.copyWith(depth: newDepth);
      }
      return point;
    }).toList();
  }

  /// Shift timestamps of all points within a range.
  ///
  /// Returns null if the shift would cause timestamps to overlap with
  /// points outside the range.
  List<DiveProfilePoint>? shiftSegmentTime(
    List<DiveProfilePoint> profile, {
    required int startTimestamp,
    required int endTimestamp,
    required int timeDelta,
  }) {
    final start = math.min(startTimestamp, endTimestamp);
    final end = math.max(startTimestamp, endTimestamp);

    // Find boundary points outside the range
    int? lastBeforeRange;
    int? firstAfterRange;

    for (final point in profile) {
      if (point.timestamp < start) {
        lastBeforeRange = point.timestamp;
      }
      if (point.timestamp > end && firstAfterRange == null) {
        firstAfterRange = point.timestamp;
      }
    }

    // Check for overlap
    final shiftedStart = start + timeDelta;
    final shiftedEnd = end + timeDelta;

    if (lastBeforeRange != null && shiftedStart <= lastBeforeRange) {
      return null;
    }
    if (firstAfterRange != null && shiftedEnd >= firstAfterRange) {
      return null;
    }

    return profile.map((point) {
      if (point.timestamp >= start && point.timestamp <= end) {
        return point.copyWith(timestamp: point.timestamp + timeDelta);
      }
      return point;
    }).toList();
  }

  /// Delete points within a timestamp range.
  ///
  /// If [interpolateGap] is true (default false), inserts a single
  /// interpolated point at the midpoint of the gap.
  List<DiveProfilePoint> deleteSegment(
    List<DiveProfilePoint> profile, {
    required int startTimestamp,
    required int endTimestamp,
    bool interpolateGap = false,
  }) {
    final start = math.min(startTimestamp, endTimestamp);
    final end = math.max(startTimestamp, endTimestamp);

    final before = profile.where((p) => p.timestamp < start).toList();
    final after = profile.where((p) => p.timestamp > end).toList();

    if (interpolateGap && before.isNotEmpty && after.isNotEmpty) {
      final left = before.last;
      final right = after.first;
      final midTimestamp = (left.timestamp + right.timestamp) ~/ 2;
      final midDepth = (left.depth + right.depth) / 2;
      final bridgePoint = DiveProfilePoint(
        timestamp: midTimestamp,
        depth: midDepth,
      );
      return [...before, bridgePoint, ...after];
    }

    return [...before, ...after];
  }
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/profile_editing_service.dart \
        test/features/dive_log/data/services/profile_editing_service_test.dart
git commit -m "feat: add range operations (shift depth, shift time, delete)"
```

---

## Task 5: ProfileEditingService -- Waypoint Interpolation

Add the `interpolateWaypoints` method for manual profile drawing.

**Files:**
- Modify: `lib/features/dive_log/data/services/profile_editing_service.dart`
- Modify: `test/features/dive_log/data/services/profile_editing_service_test.dart`

**Step 1: Write failing tests**

```dart
  group('interpolateWaypoints', () {
    test('generates points between two waypoints', () {
      final waypoints = [
        const ProfileWaypoint(timestamp: 0, depth: 0.0),
        const ProfileWaypoint(timestamp: 20, depth: 20.0),
      ];
      final profile = service.interpolateWaypoints(waypoints, intervalSeconds: 4);
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
      final profile = service.interpolateWaypoints(waypoints, intervalSeconds: 10);
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
        const ProfileWaypoint(timestamp: 240, depth: 5.0),  // ascent
        const ProfileWaypoint(timestamp: 300, depth: 0.0),  // surface
      ];
      final profile = service.interpolateWaypoints(waypoints, intervalSeconds: 4);
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
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: FAIL

**Step 3: Implement interpolateWaypoints**

Add to `ProfileEditingService`:

```dart
  /// Interpolate waypoints into a full dive profile using linear interpolation.
  ///
  /// Generates points at [intervalSeconds] intervals between consecutive
  /// waypoints. Waypoints should be sorted by timestamp.
  List<DiveProfilePoint> interpolateWaypoints(
    List<ProfileWaypoint> waypoints, {
    int intervalSeconds = 4,
  }) {
    if (waypoints.isEmpty) return [];
    if (waypoints.length == 1) {
      return [
        DiveProfilePoint(
          timestamp: waypoints.first.timestamp,
          depth: waypoints.first.depth,
        ),
      ];
    }

    // Sort by timestamp
    final sorted = List<ProfileWaypoint>.from(waypoints)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final result = <DiveProfilePoint>[];

    for (int i = 0; i < sorted.length - 1; i++) {
      final from = sorted[i];
      final to = sorted[i + 1];
      final segmentDuration = to.timestamp - from.timestamp;

      if (segmentDuration <= 0) continue;

      // Generate points at intervalSeconds intervals
      int t = from.timestamp;
      while (t < to.timestamp) {
        final progress = (t - from.timestamp) / segmentDuration;
        final depth = from.depth + (to.depth - from.depth) * progress;
        result.add(DiveProfilePoint(timestamp: t, depth: depth));
        t += intervalSeconds;
      }
    }

    // Add final waypoint
    final last = sorted.last;
    // Avoid duplicate if last interval landed exactly on the waypoint
    if (result.isEmpty || result.last.timestamp != last.timestamp) {
      result.add(DiveProfilePoint(timestamp: last.timestamp, depth: last.depth));
    }

    return result;
  }
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/services/profile_editing_service_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/data/services/profile_editing_service.dart \
        test/features/dive_log/data/services/profile_editing_service_test.dart
git commit -m "feat: add waypoint interpolation for manual profile drawing"
```

---

## Task 6: Repository -- Profile Persistence Methods

Add `saveEditedProfile`, `getProfilesBySource`, `restoreOriginalProfile` to `DiveRepositoryImpl` and filter `getDiveProfile` by `isPrimary`.

**Files:**
- Modify: `lib/features/dive_log/data/repositories/dive_repository_impl.dart:212-237` (getDiveProfile)
- Test: `test/features/dive_log/data/repositories/dive_repository_test.dart` (add profile editing tests)

**Context:**
- `getDiveProfile` is at line 212 of `dive_repository_impl.dart`
- `DiveProfilesCompanion` usage example at line 448 (in createDive)
- `isPrimary` column defined in `lib/core/database/database.dart:191`

**Step 1: Write failing tests**

Add a new group to the existing repository test file:

```dart
  group('profile editing persistence', () {
    test('saveEditedProfile stores edited points as primary', () async {
      // 1. Create a dive with profile
      // 2. Save edited profile
      // 3. getDiveProfile should return edited profile
    });

    test('saveEditedProfile demotes original to non-primary', () async {
      // 1. Create dive with profile
      // 2. Save edited profile
      // 3. getProfilesBySource should show original as non-primary
    });

    test('restoreOriginalProfile deletes edited and restores original', () async {
      // 1. Create dive with profile
      // 2. Save edited profile
      // 3. Restore original
      // 4. getDiveProfile should return original
    });

    test('getProfilesBySource returns both original and edited', () async {
      // 1. Create dive with profile
      // 2. Save edited profile
      // 3. getProfilesBySource returns map with both
    });
  });
```

Note: Exact test code depends on existing test setup patterns in `dive_repository_test.dart`. The implementing engineer should follow the file's existing patterns for database setup/teardown.

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_test.dart`
Expected: FAIL (new methods don't exist)

**Step 3: Implement repository methods**

Modify `getDiveProfile` at line 212 to filter by `isPrimary`:

```dart
  Future<List<domain.DiveProfilePoint>> getDiveProfile(String diveId) async {
    try {
      return await PerfTimer.measure('getDiveProfile', () async {
        final profileQuery = _db.select(_db.diveProfiles)
          ..where((t) => t.diveId.equals(diveId))
          ..where((t) => t.isPrimary.equals(true))
          ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
        // ... rest unchanged
      });
    }
    // ...
  }
```

Add new methods after `getDiveProfile`:

```dart
  /// Save an edited profile for a dive.
  ///
  /// Demotes all existing profiles to non-primary, then inserts
  /// the edited points as the new primary profile.
  Future<void> saveEditedProfile(
    String diveId,
    List<domain.DiveProfilePoint> editedPoints,
  ) async {
    try {
      _log.info('Saving edited profile for dive: $diveId');
      final now = DateTime.now().millisecondsSinceEpoch;

      await _db.transaction(() async {
        // Demote all existing profiles to non-primary
        await (_db.update(_db.diveProfiles)
              ..where((t) => t.diveId.equals(diveId)))
            .write(const DiveProfilesCompanion(isPrimary: Value(false)));

        // Insert edited profile points
        await _db.batch((batch) {
          for (final point in editedPoints) {
            batch.insert(
              _db.diveProfiles,
              DiveProfilesCompanion(
                id: Value(_uuid.v4()),
                diveId: Value(diveId),
                computerId: const Value('user-edited'),
                isPrimary: const Value(true),
                timestamp: Value(point.timestamp),
                depth: Value(point.depth),
                pressure: Value(point.pressure),
                temperature: Value(point.temperature),
                heartRate: Value(point.heartRate),
                heartRateSource: Value(point.heartRateSource),
                setpoint: Value(point.setpoint),
                ppO2: Value(point.ppO2),
              ),
            );
          }
        });

        // Recalculate dive stats from edited profile
        if (editedPoints.isNotEmpty) {
          double maxDepth = 0;
          double depthSum = 0;
          for (final point in editedPoints) {
            if (point.depth > maxDepth) maxDepth = point.depth;
            depthSum += point.depth;
          }
          final avgDepth = depthSum / editedPoints.length;

          await (_db.update(_db.dives)..where((t) => t.id.equals(diveId)))
              .write(DivesCompanion(
            maxDepth: Value(maxDepth),
            avgDepth: Value(avgDepth),
            updatedAt: Value(now),
          ));
        }
      });

      await _syncRepository.markRecordPending(
        entityType: 'dives',
        recordId: diveId,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      _log.info('Saved edited profile for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save edited profile for dive: $diveId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }

  /// Get all profile sources for a dive.
  ///
  /// Returns a map of computerId (null for original) to profile points.
  Future<Map<String?, List<domain.DiveProfilePoint>>> getProfilesBySource(
    String diveId,
  ) async {
    try {
      final query = _db.select(_db.diveProfiles)
        ..where((t) => t.diveId.equals(diveId))
        ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]);
      final rows = await query.get();

      final result = <String?, List<domain.DiveProfilePoint>>{};
      for (final row in rows) {
        final source = row.computerId;
        result.putIfAbsent(source, () => []).add(
          domain.DiveProfilePoint(
            timestamp: row.timestamp,
            depth: row.depth,
            pressure: row.pressure,
            temperature: row.temperature,
            heartRate: row.heartRate,
            heartRateSource: row.heartRateSource,
          ),
        );
      }
      return result;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to get profiles by source for dive: $diveId',
        e,
        stackTrace,
      );
      return {};
    }
  }

  /// Restore the original profile as primary.
  ///
  /// Deletes user-edited profiles and sets original profiles to primary.
  Future<void> restoreOriginalProfile(String diveId) async {
    try {
      _log.info('Restoring original profile for dive: $diveId');

      await _db.transaction(() async {
        // Delete user-edited profiles
        await (_db.delete(_db.diveProfiles)
              ..where((t) => t.diveId.equals(diveId))
              ..where((t) => t.computerId.equals('user-edited')))
            .go();

        // Restore original profiles to primary
        await (_db.update(_db.diveProfiles)
              ..where((t) => t.diveId.equals(diveId)))
            .write(const DiveProfilesCompanion(isPrimary: Value(true)));
      });

      SyncEventBus.notifyLocalChange();
      _log.info('Restored original profile for dive: $diveId');
    } catch (e, stackTrace) {
      _log.error(
        'Failed to restore original profile for dive: $diveId',
        e,
        stackTrace,
      );
      rethrow;
    }
  }
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_log/data/repositories/dive_repository_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/data/repositories/dive_repository_impl.dart \
        test/features/dive_log/data/repositories/dive_repository_test.dart
git commit -m "feat: add profile editing repository methods"
```

---

## Task 7: State Management -- ProfileEditorNotifier

Create the StateNotifier and state class for the editor session.

**Files:**
- Create: `lib/features/dive_log/presentation/providers/profile_editor_provider.dart`
- Test: `test/features/dive_log/presentation/providers/profile_editor_provider_test.dart`

**Context:** The app uses `StateNotifierProvider` pattern with `ConsumerWidget` / `ConsumerStatefulWidget`. See `lib/features/dive_log/presentation/providers/dive_providers.dart` for examples.

**Step 1: Write failing tests**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_editor_provider.dart';

void main() {
  late ProfileEditorNotifier notifier;
  late List<DiveProfilePoint> testProfile;

  setUp(() {
    testProfile = List.generate(
      20,
      (i) => DiveProfilePoint(timestamp: i * 4, depth: i < 10 ? i * 2.0 : (20 - i) * 2.0),
    );
    notifier = ProfileEditorNotifier(
      originalProfile: testProfile,
      editingService: ProfileEditingService(),
    );
  });

  test('initial state has no changes', () {
    expect(notifier.state.hasChanges, isFalse);
    expect(notifier.state.editedProfile, testProfile);
    expect(notifier.state.mode, EditorMode.select);
    expect(notifier.state.undoStack, isEmpty);
  });

  test('setMode changes mode', () {
    notifier.setMode(EditorMode.smooth);
    expect(notifier.state.mode, EditorMode.smooth);
  });

  test('applySmoothing creates undo entry and marks changes', () {
    notifier.applySmoothing(windowSize: 3);
    expect(notifier.state.hasChanges, isTrue);
    expect(notifier.state.undoStack.length, 1);
  });

  test('undo restores previous state', () {
    final before = notifier.state.editedProfile;
    notifier.applySmoothing(windowSize: 5);
    expect(notifier.state.editedProfile, isNot(equals(before)));
    notifier.undo();
    expect(notifier.state.editedProfile, before);
    expect(notifier.state.undoStack, isEmpty);
  });

  test('undo when stack empty is no-op', () {
    notifier.undo();
    expect(notifier.state.editedProfile, testProfile);
  });

  test('detectOutliers stores results in state', () {
    notifier.detectOutliers();
    expect(notifier.state.detectedOutliers, isNotNull);
  });

  test('setSelectedRange stores range', () {
    notifier.setSelectedRange(start: 8, end: 40);
    expect(notifier.state.selectedRange, (start: 8, end: 40));
  });

  test('clearSelectedRange removes range', () {
    notifier.setSelectedRange(start: 8, end: 40);
    notifier.clearSelectedRange();
    expect(notifier.state.selectedRange, isNull);
  });
}
```

**Step 2: Run tests to verify they fail**

Run: `flutter test test/features/dive_log/presentation/providers/profile_editor_provider_test.dart`
Expected: FAIL

**Step 3: Implement ProfileEditorNotifier**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_waypoint.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';

/// Editor modes for the profile editor.
enum EditorMode { select, smooth, outlier, draw }

/// State for the profile editor session.
class ProfileEditorState {
  final List<DiveProfilePoint> originalProfile;
  final List<DiveProfilePoint> editedProfile;
  final List<List<DiveProfilePoint>> undoStack;
  final EditorMode mode;
  final List<OutlierResult>? detectedOutliers;
  final List<ProfileWaypoint>? waypoints;
  final ({int start, int end})? selectedRange;
  final bool hasChanges;

  const ProfileEditorState({
    required this.originalProfile,
    required this.editedProfile,
    this.undoStack = const [],
    this.mode = EditorMode.select,
    this.detectedOutliers,
    this.waypoints,
    this.selectedRange,
    this.hasChanges = false,
  });

  ProfileEditorState copyWith({
    List<DiveProfilePoint>? originalProfile,
    List<DiveProfilePoint>? editedProfile,
    List<List<DiveProfilePoint>>? undoStack,
    EditorMode? mode,
    List<OutlierResult>? detectedOutliers,
    List<ProfileWaypoint>? waypoints,
    ({int start, int end})? selectedRange,
    bool? hasChanges,
    bool clearOutliers = false,
    bool clearWaypoints = false,
    bool clearRange = false,
  }) {
    return ProfileEditorState(
      originalProfile: originalProfile ?? this.originalProfile,
      editedProfile: editedProfile ?? this.editedProfile,
      undoStack: undoStack ?? this.undoStack,
      mode: mode ?? this.mode,
      detectedOutliers: clearOutliers ? null : (detectedOutliers ?? this.detectedOutliers),
      waypoints: clearWaypoints ? null : (waypoints ?? this.waypoints),
      selectedRange: clearRange ? null : (selectedRange ?? this.selectedRange),
      hasChanges: hasChanges ?? this.hasChanges,
    );
  }
}

/// Manages profile editing session state.
class ProfileEditorNotifier extends StateNotifier<ProfileEditorState> {
  final ProfileEditingService _service;

  ProfileEditorNotifier({
    required List<DiveProfilePoint> originalProfile,
    required ProfileEditingService editingService,
  })  : _service = editingService,
        super(ProfileEditorState(
          originalProfile: originalProfile,
          editedProfile: originalProfile,
        ));

  void setMode(EditorMode mode) {
    state = state.copyWith(mode: mode);
  }

  void _pushUndo() {
    state = state.copyWith(
      undoStack: [...state.undoStack, state.editedProfile],
    );
  }

  void undo() {
    if (state.undoStack.isEmpty) return;
    final previous = state.undoStack.last;
    final newStack = List<List<DiveProfilePoint>>.from(state.undoStack)..removeLast();
    state = state.copyWith(
      editedProfile: previous,
      undoStack: newStack,
      hasChanges: newStack.isNotEmpty,
    );
  }

  void applySmoothing({int windowSize = 5}) {
    _pushUndo();
    final smoothed = _service.smoothProfile(state.editedProfile, windowSize: windowSize);
    state = state.copyWith(editedProfile: smoothed, hasChanges: true);
  }

  void applySmoothingToRange({int windowSize = 5}) {
    final range = state.selectedRange;
    if (range == null) return;

    _pushUndo();
    // Extract range, smooth it, replace in full profile
    final rangePoints = state.editedProfile
        .where((p) => p.timestamp >= range.start && p.timestamp <= range.end)
        .toList();
    final smoothed = _service.smoothProfile(rangePoints, windowSize: windowSize);

    final smoothedMap = {for (final p in smoothed) p.timestamp: p};
    final result = state.editedProfile.map((p) {
      return smoothedMap[p.timestamp] ?? p;
    }).toList();

    state = state.copyWith(editedProfile: result, hasChanges: true);
  }

  void detectOutliers() {
    final outliers = _service.detectOutliers(state.editedProfile);
    state = state.copyWith(detectedOutliers: outliers);
  }

  void removeAllOutliers() {
    final outliers = state.detectedOutliers;
    if (outliers == null || outliers.isEmpty) return;

    _pushUndo();
    final cleaned = _service.removeOutliers(state.editedProfile, outliers);
    state = state.copyWith(
      editedProfile: cleaned,
      hasChanges: true,
      clearOutliers: true,
    );
  }

  void removeSelectedOutliers(List<OutlierResult> selected) {
    if (selected.isEmpty) return;
    _pushUndo();
    final cleaned = _service.removeOutliers(state.editedProfile, selected);
    // Re-detect remaining outliers
    final remaining = _service.detectOutliers(cleaned);
    state = state.copyWith(
      editedProfile: cleaned,
      detectedOutliers: remaining,
      hasChanges: true,
    );
  }

  void shiftSegmentDepth(double depthDelta) {
    final range = state.selectedRange;
    if (range == null) return;

    _pushUndo();
    final shifted = _service.shiftSegmentDepth(
      state.editedProfile,
      startTimestamp: range.start,
      endTimestamp: range.end,
      depthDelta: depthDelta,
    );
    state = state.copyWith(editedProfile: shifted, hasChanges: true);
  }

  void shiftSegmentTime(int timeDelta) {
    final range = state.selectedRange;
    if (range == null) return;

    final shifted = _service.shiftSegmentTime(
      state.editedProfile,
      startTimestamp: range.start,
      endTimestamp: range.end,
      timeDelta: timeDelta,
    );
    if (shifted == null) return; // Overlap detected

    _pushUndo();
    state = state.copyWith(editedProfile: shifted, hasChanges: true);
  }

  void deleteSegment({bool interpolateGap = false}) {
    final range = state.selectedRange;
    if (range == null) return;

    _pushUndo();
    final result = _service.deleteSegment(
      state.editedProfile,
      startTimestamp: range.start,
      endTimestamp: range.end,
      interpolateGap: interpolateGap,
    );
    state = state.copyWith(
      editedProfile: result,
      hasChanges: true,
      clearRange: true,
    );
  }

  void setSelectedRange({required int start, required int end}) {
    state = state.copyWith(selectedRange: (start: start, end: end));
  }

  void clearSelectedRange() {
    state = state.copyWith(clearRange: true);
  }

  // --- Draw mode ---

  void addWaypoint(ProfileWaypoint waypoint) {
    final current = state.waypoints ?? [];
    final updated = [...current, waypoint]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(waypoints: updated);
  }

  void removeWaypoint(int index) {
    final current = state.waypoints;
    if (current == null || index >= current.length) return;
    final updated = List<ProfileWaypoint>.from(current)..removeAt(index);
    state = state.copyWith(waypoints: updated);
  }

  void updateWaypoint(int index, ProfileWaypoint waypoint) {
    final current = state.waypoints;
    if (current == null || index >= current.length) return;
    final updated = List<ProfileWaypoint>.from(current)
      ..[index] = waypoint;
    updated.sort((a, b) => a.timestamp.compareTo(b.timestamp));
    state = state.copyWith(waypoints: updated);
  }

  void clearWaypoints() {
    state = state.copyWith(clearWaypoints: true);
  }

  void generateProfileFromWaypoints({int intervalSeconds = 4}) {
    final waypoints = state.waypoints;
    if (waypoints == null || waypoints.isEmpty) return;

    _pushUndo();
    final generated = _service.interpolateWaypoints(
      waypoints,
      intervalSeconds: intervalSeconds,
    );
    state = state.copyWith(editedProfile: generated, hasChanges: true);
  }
}
```

**Step 4: Run tests**

Run: `flutter test test/features/dive_log/presentation/providers/profile_editor_provider_test.dart`
Expected: ALL PASS

**Step 5: Commit**

```bash
git add lib/features/dive_log/presentation/providers/profile_editor_provider.dart \
        test/features/dive_log/presentation/providers/profile_editor_provider_test.dart
git commit -m "feat: add ProfileEditorNotifier state management"
```

---

## Task 8: Outlier Suggestion Provider

Create the `FutureProvider` that detects outliers in the background for the dive detail badge.

**Files:**
- Create: `lib/features/dive_log/presentation/providers/outlier_suggestion_provider.dart`

**Step 1: Implement provider**

```dart
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';
import 'package:submersion/features/dive_log/data/services/profile_editing_service.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

/// Detects outliers in a dive's profile for showing suggestion badges.
///
/// Returns the list of detected outliers (empty if none found).
/// Used on DiveDetailPage to show "X potential outliers detected" chip.
final outlierSuggestionProvider =
    FutureProvider.family<List<OutlierResult>, String>((ref, diveId) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  if (dive == null || dive.profile.length < 10) return [];

  final service = ProfileEditingService();
  return service.detectOutliers(dive.profile);
});
```

**Step 2: Commit**

```bash
git add lib/features/dive_log/presentation/providers/outlier_suggestion_provider.dart
git commit -m "feat: add outlier suggestion provider for dive detail badge"
```

---

## Task 9: ProfileEditorChart Widget

Build the simplified chart widget for the editor page.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/profile_editor_chart.dart`

**Context:** The existing `DiveProfileChart` in `lib/features/dive_log/presentation/widgets/dive_profile_chart.dart` uses `fl_chart` `LineChart` with `LineChartData`. This new chart should be much simpler -- depth vs time only, with overlay markers for outliers/waypoints.

**Step 1: Implement ProfileEditorChart**

This is a `ConsumerStatefulWidget` that renders:
- An fl_chart `LineChart` with depth vs time
- Original profile as a faded dashed line (using `dashArray`)
- Edited profile as a bold primary-colored line
- Outlier markers (red circles) when `outliers` is provided
- Waypoint markers (draggable blue circles) when `waypoints` is provided
- Range selection shading (semi-transparent overlay between start/end handles)
- Zoom/pan via `FlTouchData`

Key properties:
```dart
class ProfileEditorChart extends ConsumerStatefulWidget {
  final List<DiveProfilePoint> originalProfile;
  final List<DiveProfilePoint> editedProfile;
  final List<OutlierResult>? outliers;
  final List<ProfileWaypoint>? waypoints;
  final ({int start, int end})? selectedRange;
  final EditorMode mode;
  final void Function(int timestamp, double depth)? onTap;
  final void Function(int waypointIndex, int timestamp, double depth)? onWaypointDrag;
  final void Function(int startTimestamp, int endTimestamp)? onRangeChanged;
}
```

Implementation details:
- Chart Y axis inverted (deeper = lower, matching existing chart convention)
- Unit-aware labels using `UnitFormatter` from `lib/core/utils/unit_formatter.dart`
- Respects active diver's unit settings (meters/feet)
- Maximum chart height: 300px
- Gestures: pinch zoom, pan, tap-to-place (draw mode)

This is a UI-heavy widget -- full code is too long for this plan. Implement following the patterns in `dive_profile_chart.dart` but with ~200 lines instead of ~800. Strip everything except depth line, original reference line, markers, and range shading.

**Step 2: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/profile_editor_chart.dart
git commit -m "feat: add ProfileEditorChart widget"
```

---

## Task 10: EditorToolbar & EditorContextPanel Widgets

Build the mode selector toolbar and mode-specific context panel.

**Files:**
- Create: `lib/features/dive_log/presentation/widgets/editor_toolbar.dart`
- Create: `lib/features/dive_log/presentation/widgets/editor_context_panel.dart`

**Step 1: Implement EditorToolbar**

A row of `SegmentedButton<EditorMode>` or `ToggleButtons`:

```dart
class EditorToolbar extends StatelessWidget {
  final EditorMode mode;
  final void Function(EditorMode) onModeChanged;
  // ...
}
```

4 modes: Select (icon: `touch_app`), Smooth (icon: `auto_fix_high`), Outlier (icon: `warning_amber`), Draw (icon: `draw`).

**Step 2: Implement EditorContextPanel**

Shows different controls based on mode:

- **Select**: Depth shift input (+ / - buttons or slider), Time shift input, Delete segment button, Smooth selection button
- **Smooth**: Window size selector (Small/Medium/Large chips), "Apply to All" / "Apply to Selection" buttons
- **Outlier**: Outlier count badge, list of outliers with timestamps/depths, "Remove All" / "Remove Selected" buttons
- **Draw**: "Clear Waypoints" button, "Generate Profile" button, interval selector

```dart
class EditorContextPanel extends ConsumerWidget {
  final EditorMode mode;
  final String diveId;
  // ...
}
```

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/widgets/editor_toolbar.dart \
        lib/features/dive_log/presentation/widgets/editor_context_panel.dart
git commit -m "feat: add editor toolbar and context panel widgets"
```

---

## Task 11: ProfileEditorPage

Assemble the full editor page and register the route.

**Files:**
- Create: `lib/features/dive_log/presentation/pages/profile_editor_page.dart`
- Modify: `lib/core/router/app_router.dart:237-244` (add route)

**Step 1: Implement ProfileEditorPage**

A `ConsumerStatefulWidget` that:
1. Loads the dive's profile via `diveProvider(diveId)`
2. Creates a `ProfileEditorNotifier` (use `StateNotifierProvider.autoDispose`)
3. Renders `AppBar` with "Edit Profile" title, Undo and Save action buttons
4. Renders `ProfileEditorChart`, `EditorToolbar`, `EditorContextPanel`
5. Handles save flow: confirmation dialog, call repository `saveEditedProfile`, pop
6. Handles back navigation: unsaved changes dialog with `WillPopScope` / `PopScope`

```dart
class ProfileEditorPage extends ConsumerStatefulWidget {
  final String diveId;
  final EditorMode? initialMode; // for outlier suggestion deep link

  const ProfileEditorPage({
    super.key,
    required this.diveId,
    this.initialMode,
  });
  // ...
}
```

**Step 2: Register route**

In `lib/core/router/app_router.dart`, after the existing `editDive` route (line 243), add:

```dart
GoRoute(
  path: 'edit-profile',
  name: 'editProfile',
  builder: (context, state) => ProfileEditorPage(
    diveId: state.pathParameters['diveId']!,
    initialMode: state.uri.queryParameters['mode'] != null
        ? EditorMode.values.byName(state.uri.queryParameters['mode']!)
        : null,
  ),
),
```

Add import for `ProfileEditorPage` at the top of the router file.

**Step 3: Commit**

```bash
git add lib/features/dive_log/presentation/pages/profile_editor_page.dart \
        lib/core/router/app_router.dart
git commit -m "feat: add ProfileEditorPage and register route"
```

---

## Task 12: DiveDetailPage Integration

Add "Edit Profile" button and outlier suggestion badge to the dive detail page.

**Files:**
- Modify: `lib/features/dive_log/presentation/pages/dive_detail_page.dart`

**Step 1: Add entry points**

In the profile chart section of `DiveDetailPage`:

1. Add an "Edit Profile" `IconButton` or overflow menu item near the chart
2. Watch `outlierSuggestionProvider(diveId)` and show a chip when outliers detected
3. The chip navigates to `context.pushNamed('editProfile', pathParameters: {'diveId': diveId}, queryParameters: {'mode': 'outlier'})`
4. The edit button navigates to `context.pushNamed('editProfile', pathParameters: {'diveId': diveId})`

Add imports for `outlier_suggestion_provider.dart` and the `EditorMode` enum.

**Step 2: Commit**

```bash
git add lib/features/dive_log/presentation/pages/dive_detail_page.dart
git commit -m "feat: add profile editor entry points to dive detail page"
```

---

## Task 13: Format, Analyze, Full Test Suite

Run formatting, static analysis, and full test suite.

**Step 1: Format**

Run: `dart format lib/ test/`

**Step 2: Analyze**

Run: `flutter analyze`
Fix any issues.

**Step 3: Full test suite**

Run: `flutter test`
Fix any failures.

**Step 4: Commit**

```bash
git add -A
git commit -m "chore: format and fix analysis issues"
```

---

## Task 14: Update FEATURE_ROADMAP.md

Mark profile editing tasks as complete.

**Files:**
- Modify: `FEATURE_ROADMAP.md`

**Step 1: Update status**

Change the profile editing section to show implemented status:
- Smoothing / cleaning bad samples: Implemented
- Manual profile drawing: Implemented
- Segment editing: Implemented

Mark tasks as done:
- [x] Profile outlier detection algorithm
- [x] Smoothing algorithm (weighted moving average)
- [x] Manual profile editor with waypoint drawing
- [x] Segment selection and adjustment UI

**Step 2: Commit**

```bash
git add FEATURE_ROADMAP.md
git commit -m "docs: mark profile editing features as implemented"
```

---

## Summary

| Task | Component | Est. Complexity |
|------|-----------|----------------|
| 1 | Domain entities | Low |
| 2 | Outlier detection | Medium |
| 3 | Smoothing & removal | Medium |
| 4 | Range operations | Medium |
| 5 | Waypoint interpolation | Low |
| 6 | Repository persistence | Medium |
| 7 | StateNotifier | Medium |
| 8 | Outlier suggestion provider | Low |
| 9 | ProfileEditorChart | High |
| 10 | Toolbar & context panel | Medium |
| 11 | ProfileEditorPage | Medium |
| 12 | DiveDetailPage integration | Low |
| 13 | Format, analyze, test | Low |
| 14 | Update roadmap | Low |
