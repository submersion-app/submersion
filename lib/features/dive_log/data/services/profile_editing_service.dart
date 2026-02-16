import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';

/// Service for editing dive profiles.
///
/// Pure Dart -- no Flutter dependencies. All methods are stateless
/// and return new lists (never mutate input).
class ProfileEditingService {
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

      final smoothedDepth = usedWeightSum > 0
          ? weightedDepth / usedWeightSum
          : profile[i].depth;

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
    if (outliers.isEmpty) return List.of(profile);

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
      final isPhysicallyImpossible =
          timeDiff > 0 && delta.abs() / timeDiff > maxRateMetersPerSecond;

      // Z-score check: compare delta to local window
      final windowStart = math.max(0, i - halfWindow);
      final windowEnd = math.min(deltas.length, i + halfWindow + 1);
      final windowDeltas = deltas.sublist(windowStart, windowEnd);

      final mean = windowDeltas.reduce((a, b) => a + b) / windowDeltas.length;
      final variance =
          windowDeltas.fold<double>(
            0.0,
            (sum, d) => sum + (d - mean) * (d - mean),
          ) /
          windowDeltas.length;
      final stddev = math.sqrt(variance);

      final zScore = stddev > 0 ? (delta - mean).abs() / stddev : 0.0;
      final isZScoreOutlier = zScore > zScoreThreshold;

      if (isPhysicallyImpossible || isZScoreOutlier) {
        results.add(
          OutlierResult(
            index: pointIndex,
            timestamp: profile[pointIndex].timestamp,
            depth: profile[pointIndex].depth,
            depthDelta: delta,
            zScore: zScore,
            isPhysicallyImpossible: isPhysicallyImpossible,
          ),
        );
      }
    }

    return results;
  }

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
}
