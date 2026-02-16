import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/outlier_result.dart';

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
}
