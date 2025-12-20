import 'dart:math' as math;

import '../constants/enums.dart';

/// Represents an ascent rate data point on the dive profile.
class AscentRatePoint {
  /// Timestamp in seconds from dive start
  final int timestamp;

  /// Depth at this point in meters
  final double depth;

  /// Ascent rate in meters per minute (negative = descending)
  final double rateMetersPerMin;

  /// Category based on rate
  final AscentRateCategory category;

  const AscentRatePoint({
    required this.timestamp,
    required this.depth,
    required this.rateMetersPerMin,
    required this.category,
  });

  /// Whether this is a descent (negative rate = going deeper)
  bool get isDescending => rateMetersPerMin < 0;

  /// Whether this is an ascent (positive rate = going shallower)
  bool get isAscending => rateMetersPerMin > 0;

  /// Whether the diver is at a constant depth (within tolerance)
  bool get isConstant => rateMetersPerMin.abs() < 0.5;

  /// Formatted rate string
  String get rateFormatted {
    if (isConstant) return '0 m/min';
    final sign = rateMetersPerMin > 0 ? '+' : '';
    return '$sign${rateMetersPerMin.toStringAsFixed(1)} m/min';
  }
}

/// Represents an ascent rate violation event.
class AscentRateViolation {
  /// Start timestamp of violation
  final int startTimestamp;

  /// End timestamp of violation
  final int endTimestamp;

  /// Maximum rate during violation (m/min)
  final double maxRate;

  /// Depth at max rate (meters)
  final double depthAtMaxRate;

  /// Whether this was a critical violation
  final bool isCritical;

  const AscentRateViolation({
    required this.startTimestamp,
    required this.endTimestamp,
    required this.maxRate,
    required this.depthAtMaxRate,
    required this.isCritical,
  });

  /// Duration of violation in seconds
  int get durationSeconds => endTimestamp - startTimestamp;

  /// Duration formatted
  String get durationFormatted {
    final seconds = durationSeconds;
    if (seconds < 60) return '${seconds}s';
    return '${seconds ~/ 60}m ${seconds % 60}s';
  }
}

/// Calculator for ascent rates and violations.
class AscentRateCalculator {
  /// Warning threshold in m/min (default 9)
  final double warningThreshold;

  /// Critical threshold in m/min (default 12)
  final double criticalThreshold;

  /// Number of points to use for smoothing (moving average)
  final int smoothingWindow;

  const AscentRateCalculator({
    this.warningThreshold = 9.0,
    this.criticalThreshold = 12.0,
    this.smoothingWindow = 3,
  });

  /// Calculate ascent rate between two profile points.
  ///
  /// [depth1] and [depth2] are depths in meters.
  /// [time1] and [time2] are timestamps in seconds.
  /// Returns rate in meters per minute (positive = ascending).
  static double calculateRate(
    double depth1,
    double depth2,
    int time1,
    int time2,
  ) {
    if (time2 == time1) return 0.0;

    final depthChange = depth1 - depth2; // Positive when ascending
    final timeChange = (time2 - time1) / 60.0; // Convert to minutes

    return depthChange / timeChange;
  }

  /// Get the ascent rate category for a given rate.
  AscentRateCategory categorize(double rateMetersPerMin) {
    final absRate = rateMetersPerMin.abs();
    if (absRate <= warningThreshold) return AscentRateCategory.safe;
    if (absRate <= criticalThreshold) return AscentRateCategory.warning;
    return AscentRateCategory.danger;
  }

  /// Calculate ascent rates for all points in a dive profile.
  ///
  /// [depths] is a list of depths in meters.
  /// [timestamps] is a list of timestamps in seconds.
  /// Returns a list of [AscentRatePoint] for each point.
  List<AscentRatePoint> calculateProfileRates(
    List<double> depths,
    List<int> timestamps,
  ) {
    if (depths.length != timestamps.length || depths.isEmpty) {
      return [];
    }

    if (depths.length == 1) {
      return [
        AscentRatePoint(
          timestamp: timestamps[0],
          depth: depths[0],
          rateMetersPerMin: 0.0,
          category: AscentRateCategory.safe,
        ),
      ];
    }

    final rates = <AscentRatePoint>[];

    // Calculate raw rates
    final rawRates = <double>[0.0]; // First point has no rate
    for (int i = 1; i < depths.length; i++) {
      final rate = calculateRate(
        depths[i - 1],
        depths[i],
        timestamps[i - 1],
        timestamps[i],
      );
      rawRates.add(rate);
    }

    // Apply smoothing if window > 1
    final smoothedRates =
        smoothingWindow > 1 ? _smoothRates(rawRates) : rawRates;

    // Create rate points
    for (int i = 0; i < depths.length; i++) {
      final rate = smoothedRates[i];
      rates.add(AscentRatePoint(
        timestamp: timestamps[i],
        depth: depths[i],
        rateMetersPerMin: rate,
        category: categorize(rate),
      ));
    }

    return rates;
  }

  /// Apply moving average smoothing to rates.
  List<double> _smoothRates(List<double> rates) {
    if (rates.length < smoothingWindow) return rates;

    final smoothed = <double>[];
    final halfWindow = smoothingWindow ~/ 2;

    for (int i = 0; i < rates.length; i++) {
      final start = math.max(0, i - halfWindow);
      final end = math.min(rates.length, i + halfWindow + 1);

      double sum = 0;
      for (int j = start; j < end; j++) {
        sum += rates[j];
      }
      smoothed.add(sum / (end - start));
    }

    return smoothed;
  }

  /// Find all ascent rate violations in a profile.
  List<AscentRateViolation> findViolations(List<AscentRatePoint> ratePoints) {
    final violations = <AscentRateViolation>[];

    int? violationStart;
    double maxRate = 0;
    double depthAtMax = 0;
    bool hasCritical = false;

    for (int i = 0; i < ratePoints.length; i++) {
      final point = ratePoints[i];
      final isViolation = point.category != AscentRateCategory.safe;

      if (isViolation) {
        if (violationStart == null) {
          // Start new violation
          violationStart = point.timestamp;
          maxRate = point.rateMetersPerMin;
          depthAtMax = point.depth;
          hasCritical = point.category == AscentRateCategory.danger;
        } else {
          // Continue violation
          if (point.rateMetersPerMin.abs() > maxRate.abs()) {
            maxRate = point.rateMetersPerMin;
            depthAtMax = point.depth;
          }
          if (point.category == AscentRateCategory.danger) {
            hasCritical = true;
          }
        }
      } else if (violationStart != null) {
        // End of violation
        violations.add(AscentRateViolation(
          startTimestamp: violationStart,
          endTimestamp: ratePoints[i - 1].timestamp,
          maxRate: maxRate,
          depthAtMaxRate: depthAtMax,
          isCritical: hasCritical,
        ));
        violationStart = null;
        maxRate = 0;
        depthAtMax = 0;
        hasCritical = false;
      }
    }

    // Handle violation that extends to end of dive
    if (violationStart != null && ratePoints.isNotEmpty) {
      violations.add(AscentRateViolation(
        startTimestamp: violationStart,
        endTimestamp: ratePoints.last.timestamp,
        maxRate: maxRate,
        depthAtMaxRate: depthAtMax,
        isCritical: hasCritical,
      ));
    }

    return violations;
  }

  /// Get the maximum ascent rate from a list of rate points.
  double getMaxAscentRate(List<AscentRatePoint> ratePoints) {
    if (ratePoints.isEmpty) return 0.0;

    double maxRate = 0.0;
    for (final point in ratePoints) {
      if (point.rateMetersPerMin > maxRate) {
        maxRate = point.rateMetersPerMin;
      }
    }
    return maxRate;
  }

  /// Get the maximum descent rate from a list of rate points.
  double getMaxDescentRate(List<AscentRatePoint> ratePoints) {
    if (ratePoints.isEmpty) return 0.0;

    double maxRate = 0.0;
    for (final point in ratePoints) {
      if (point.rateMetersPerMin < maxRate) {
        maxRate = point.rateMetersPerMin;
      }
    }
    return maxRate.abs(); // Return as positive value
  }

  /// Get statistics about ascent rates in a dive.
  AscentRateStats getStats(List<AscentRatePoint> ratePoints) {
    if (ratePoints.isEmpty) {
      return const AscentRateStats(
        maxAscentRate: 0,
        maxDescentRate: 0,
        averageAscentRate: 0,
        averageDescentRate: 0,
        violationCount: 0,
        criticalViolationCount: 0,
        timeInViolation: 0,
      );
    }

    double maxAscent = 0;
    double maxDescent = 0;
    double sumAscent = 0;
    double sumDescent = 0;
    int ascentCount = 0;
    int descentCount = 0;

    for (final point in ratePoints) {
      if (point.rateMetersPerMin > 0) {
        if (point.rateMetersPerMin > maxAscent) {
          maxAscent = point.rateMetersPerMin;
        }
        sumAscent += point.rateMetersPerMin;
        ascentCount++;
      } else if (point.rateMetersPerMin < 0) {
        final absRate = point.rateMetersPerMin.abs();
        if (absRate > maxDescent) {
          maxDescent = absRate;
        }
        sumDescent += absRate;
        descentCount++;
      }
    }

    final violations = findViolations(ratePoints);
    int totalViolationTime = 0;
    for (final v in violations) {
      totalViolationTime += v.durationSeconds;
    }

    return AscentRateStats(
      maxAscentRate: maxAscent,
      maxDescentRate: maxDescent,
      averageAscentRate: ascentCount > 0 ? sumAscent / ascentCount : 0,
      averageDescentRate: descentCount > 0 ? sumDescent / descentCount : 0,
      violationCount: violations.length,
      criticalViolationCount: violations.where((v) => v.isCritical).length,
      timeInViolation: totalViolationTime,
    );
  }
}

/// Statistics about ascent rates in a dive.
class AscentRateStats {
  /// Maximum ascent rate (m/min)
  final double maxAscentRate;

  /// Maximum descent rate (m/min, positive value)
  final double maxDescentRate;

  /// Average ascent rate (m/min)
  final double averageAscentRate;

  /// Average descent rate (m/min, positive value)
  final double averageDescentRate;

  /// Number of distinct violation periods
  final int violationCount;

  /// Number of critical violation periods
  final int criticalViolationCount;

  /// Total time in violation (seconds)
  final int timeInViolation;

  const AscentRateStats({
    required this.maxAscentRate,
    required this.maxDescentRate,
    required this.averageAscentRate,
    required this.averageDescentRate,
    required this.violationCount,
    required this.criticalViolationCount,
    required this.timeInViolation,
  });

  /// Whether any violations occurred
  bool get hasViolations => violationCount > 0;

  /// Whether any critical violations occurred
  bool get hasCriticalViolations => criticalViolationCount > 0;
}
