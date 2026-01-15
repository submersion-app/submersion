import 'dart:math' as math;

import 'package:submersion/core/deco/entities/o2_exposure.dart';

/// Calculator for oxygen toxicity (CNS and OTU).
///
/// Calculates:
/// - CNS% (Central Nervous System toxicity) using NOAA tables
/// - OTU (Oxygen Tolerance Units) for pulmonary toxicity
/// - ppO2 at depth for various gas mixes
class O2ToxicityCalculator {
  /// Warning threshold for ppO2 (default 1.4 bar)
  final double ppO2WarningThreshold;

  /// Critical threshold for ppO2 (default 1.6 bar)
  final double ppO2CriticalThreshold;

  /// CNS warning threshold percentage (default 80%)
  final int cnsWarningThreshold;

  const O2ToxicityCalculator({
    this.ppO2WarningThreshold = 1.4,
    this.ppO2CriticalThreshold = 1.6,
    this.cnsWarningThreshold = 80,
  });

  /// Calculate ppO2 at a given depth for a gas mix.
  ///
  /// [depthMeters] is the depth in meters.
  /// [o2Fraction] is the oxygen fraction (0.0-1.0).
  /// Returns ppO2 in bar.
  static double calculatePpO2(double depthMeters, double o2Fraction) {
    final ambientPressure = 1.0 + (depthMeters / 10.0);
    return ambientPressure * o2Fraction;
  }

  /// Calculate the Maximum Operating Depth (MOD) for a gas.
  ///
  /// [o2Fraction] is the oxygen fraction (0.0-1.0).
  /// [maxPpO2] is the maximum allowed ppO2 (typically 1.4 or 1.6).
  /// Returns MOD in meters.
  static double calculateMod(double o2Fraction, {double maxPpO2 = 1.4}) {
    if (o2Fraction <= 0) return 0;
    return ((maxPpO2 / o2Fraction) - 1.0) * 10.0;
  }

  /// Calculate the Equivalent Narcotic Depth (END) for a gas.
  ///
  /// [depthMeters] is the actual depth in meters.
  /// [n2Fraction] is the nitrogen fraction (0.0-1.0).
  /// Returns END in meters.
  static double calculateEnd(double depthMeters, double n2Fraction) {
    // END = (depth + 10) * (N2 fraction / 0.79) - 10
    // Using air narcosis as baseline (0.79 N2)
    final ambientPressure = 1.0 + (depthMeters / 10.0);
    final n2Pressure = ambientPressure * n2Fraction;
    return (n2Pressure / 0.79 - 1.0) * 10.0;
  }

  /// Get CNS% accumulation rate per minute at given ppO2.
  ///
  /// Based on NOAA Diving Manual oxygen exposure limits.
  /// Returns CNS% per minute.
  double getCnsPerMinute(double ppO2) {
    return CnsTable.cnsPerMinute(ppO2);
  }

  /// Calculate CNS% for a single time segment at constant ppO2.
  ///
  /// [ppO2] is the partial pressure of oxygen in bar.
  /// [durationSeconds] is the duration in seconds.
  /// Returns CNS% accumulated.
  double calculateCnsForSegment(double ppO2, int durationSeconds) {
    return CnsTable.cnsForSegment(ppO2, durationSeconds);
  }

  /// Calculate OTU for a single time segment at constant ppO2.
  ///
  /// [ppO2] is the partial pressure of oxygen in bar.
  /// [durationSeconds] is the duration in seconds.
  /// Returns OTU accumulated.
  double calculateOtuForSegment(double ppO2, int durationSeconds) {
    return _calculateOtu(ppO2, durationSeconds);
  }

  /// Calculate OTU using the standard formula.
  ///
  /// OTU = t * ((ppO2 - 0.5) / 0.5)^0.833
  double _calculateOtu(double ppO2, int durationSeconds) {
    if (ppO2 <= 0.5) return 0.0;

    final minutes = durationSeconds / 60.0;
    final factor = (ppO2 - 0.5) / 0.5;
    return minutes * math.pow(factor, 5.0 / 6.0);
  }

  /// Calculate oxygen exposure for an entire dive profile.
  ///
  /// [depths] is a list of depths in meters.
  /// [timestamps] is a list of timestamps in seconds.
  /// [o2Fraction] is the oxygen fraction of the gas (0.0-1.0).
  /// [startCns] is the starting CNS% (from previous dives).
  /// Returns an [O2Exposure] with calculated values.
  O2Exposure calculateDiveExposure({
    required List<double> depths,
    required List<int> timestamps,
    required double o2Fraction,
    double startCns = 0.0,
  }) {
    if (depths.length != timestamps.length || depths.isEmpty) {
      return O2Exposure(cnsStart: startCns, cnsEnd: startCns);
    }

    double totalCns = 0.0;
    double totalOtu = 0.0;
    double maxPpO2 = 0.0;
    double depthAtMaxPpO2 = 0.0;
    int timeAboveWarning = 0;
    int timeAboveCritical = 0;

    for (int i = 1; i < depths.length; i++) {
      // Use average depth for segment
      final avgDepth = (depths[i - 1] + depths[i]) / 2.0;
      final duration = timestamps[i] - timestamps[i - 1];

      final ppO2 = calculatePpO2(avgDepth, o2Fraction);

      // Track max ppO2
      if (ppO2 > maxPpO2) {
        maxPpO2 = ppO2;
        depthAtMaxPpO2 = avgDepth;
      }

      // Calculate CNS and OTU for this segment
      totalCns += calculateCnsForSegment(ppO2, duration);
      totalOtu += _calculateOtu(ppO2, duration);

      // Track time above thresholds
      if (ppO2 > ppO2CriticalThreshold) {
        timeAboveCritical += duration;
        timeAboveWarning += duration;
      } else if (ppO2 > ppO2WarningThreshold) {
        timeAboveWarning += duration;
      }
    }

    return O2Exposure(
      cnsStart: startCns,
      cnsEnd: startCns + totalCns,
      otu: totalOtu,
      maxPpO2: maxPpO2,
      maxPpO2Depth: depthAtMaxPpO2,
      timeAboveWarning: timeAboveWarning,
      timeAboveCritical: timeAboveCritical,
    );
  }

  /// Calculate oxygen exposure with multiple gases (gas switches).
  ///
  /// [depths] is a list of depths in meters.
  /// [timestamps] is a list of timestamps in seconds.
  /// [gasSwitches] maps timestamp to new O2 fraction.
  /// [initialO2Fraction] is the starting gas O2 fraction.
  /// [startCns] is the starting CNS% (from previous dives).
  O2Exposure calculateMultiGasExposure({
    required List<double> depths,
    required List<int> timestamps,
    required Map<int, double> gasSwitches,
    required double initialO2Fraction,
    double startCns = 0.0,
  }) {
    if (depths.length != timestamps.length || depths.isEmpty) {
      return O2Exposure(cnsStart: startCns, cnsEnd: startCns);
    }

    double totalCns = 0.0;
    double totalOtu = 0.0;
    double maxPpO2 = 0.0;
    double depthAtMaxPpO2 = 0.0;
    int timeAboveWarning = 0;
    int timeAboveCritical = 0;
    double currentO2Fraction = initialO2Fraction;

    for (int i = 1; i < depths.length; i++) {
      // Check for gas switch at this point
      if (gasSwitches.containsKey(timestamps[i])) {
        currentO2Fraction = gasSwitches[timestamps[i]]!;
      }

      final avgDepth = (depths[i - 1] + depths[i]) / 2.0;
      final duration = timestamps[i] - timestamps[i - 1];

      final ppO2 = calculatePpO2(avgDepth, currentO2Fraction);

      if (ppO2 > maxPpO2) {
        maxPpO2 = ppO2;
        depthAtMaxPpO2 = avgDepth;
      }

      totalCns += calculateCnsForSegment(ppO2, duration);
      totalOtu += _calculateOtu(ppO2, duration);

      if (ppO2 > ppO2CriticalThreshold) {
        timeAboveCritical += duration;
        timeAboveWarning += duration;
      } else if (ppO2 > ppO2WarningThreshold) {
        timeAboveWarning += duration;
      }
    }

    return O2Exposure(
      cnsStart: startCns,
      cnsEnd: startCns + totalCns,
      otu: totalOtu,
      maxPpO2: maxPpO2,
      maxPpO2Depth: depthAtMaxPpO2,
      timeAboveWarning: timeAboveWarning,
      timeAboveCritical: timeAboveCritical,
    );
  }

  /// Calculate ppO2 curve for a dive profile (Open Circuit).
  ///
  /// Returns a list of ppO2 values corresponding to each depth point.
  List<double> calculatePpO2Curve(List<double> depths, double o2Fraction) {
    return depths.map((d) => calculatePpO2(d, o2Fraction)).toList();
  }

  /// Calculate ppO2 curve for a CCR dive profile.
  ///
  /// For CCR, ppO2 equals the setpoint (constant) throughout the dive.
  /// Optionally uses different setpoints for different depth phases.
  ///
  /// [depths] - depth at each sample point
  /// [setpointHigh] - working setpoint (used for bottom phase)
  /// [setpointLow] - optional low setpoint for descent/ascent
  /// [lowSetpointMaxDepth] - depth at which to switch from low to high setpoint
  List<double> calculatePpO2CurveCCR(
    List<double> depths, {
    required double setpointHigh,
    double? setpointLow,
    double lowSetpointMaxDepth = 6.0,
  }) {
    if (setpointLow == null) {
      // Single setpoint for entire dive
      return List.filled(depths.length, setpointHigh);
    }

    // Variable setpoint based on depth phase
    return depths.map((depth) {
      // Use low setpoint for shallow depths (descent/ascent)
      if (depth < lowSetpointMaxDepth) {
        return setpointLow;
      }
      return setpointHigh;
    }).toList();
  }

  /// Calculate ppO2 curve for an SCR dive profile.
  ///
  /// For SCR, ppO2 varies with depth and is based on the steady-state
  /// loop FO2 which depends on injection rate and assumed VO2.
  ///
  /// Returns average ppO2 at each depth (between min and max workload values).
  List<double> calculatePpO2CurveSCR(
    List<double> depths, {
    required double injectionRateLpm,
    required double supplyO2Percent,
    double vo2 = 1.3, // Average metabolic rate
  }) {
    // Calculate steady-state loop FO2
    final supplyO2Fraction = supplyO2Percent / 100.0;

    // Avoid division by zero
    if (injectionRateLpm <= vo2) {
      // Invalid configuration - return zeros (would cause hypoxia)
      return List.filled(depths.length, 0.0);
    }

    // Steady-state loop FO2 formula:
    // FO2 = (Qmix × Fmix - VO2) / (Qmix - VO2)
    final loopFo2 =
        (injectionRateLpm * supplyO2Fraction - vo2) / (injectionRateLpm - vo2);

    // Calculate ppO2 at each depth using the loop FO2
    return depths.map((depth) {
      final ambientPressure = 1.0 + (depth / 10.0);
      return ambientPressure * loopFo2;
    }).toList();
  }

  /// Calculate CNS recovery after surface interval.
  ///
  /// [currentCns] is the current CNS%.
  /// [surfaceIntervalMinutes] is time at surface in minutes.
  /// Returns remaining CNS%.
  double calculateCnsRecovery(double currentCns, int surfaceIntervalMinutes) {
    return CnsTable.cnsAfterSurfaceInterval(currentCns, surfaceIntervalMinutes);
  }

  /// Check if ppO2 is safe for the given depth and gas.
  ///
  /// Returns true if ppO2 is at or below the warning threshold.
  bool isPpO2Safe(double depthMeters, double o2Fraction) {
    final ppO2 = calculatePpO2(depthMeters, o2Fraction);
    return ppO2 <= ppO2WarningThreshold;
  }

  /// Get ppO2 status for display.
  PpO2Status getPpO2Status(double ppO2) {
    if (ppO2 <= 0.5) return PpO2Status.low;
    if (ppO2 <= ppO2WarningThreshold) return PpO2Status.safe;
    if (ppO2 <= ppO2CriticalThreshold) return PpO2Status.warning;
    return PpO2Status.critical;
  }

  /// Get CNS status for display.
  CnsStatus getCnsStatus(double cns) {
    if (cns < cnsWarningThreshold) return CnsStatus.safe;
    if (cns < 100) return CnsStatus.warning;
    return CnsStatus.critical;
  }
}

/// ppO2 status levels.
enum PpO2Status {
  low('Low - Hypoxia Risk'),
  safe('Safe'),
  warning('Warning'),
  critical('Critical - CNS Risk');

  final String displayName;
  const PpO2Status(this.displayName);
}

/// CNS status levels.
enum CnsStatus {
  safe('Safe'),
  warning('Warning'),
  critical('Critical');

  final String displayName;
  const CnsStatus(this.displayName);
}

/// Represents a ppO2 data point for charting.
class PpO2Point {
  /// Timestamp in seconds
  final int timestamp;

  /// Depth in meters
  final double depth;

  /// ppO2 in bar
  final double ppO2;

  /// Status at this point
  final PpO2Status status;

  const PpO2Point({
    required this.timestamp,
    required this.depth,
    required this.ppO2,
    required this.status,
  });
}
