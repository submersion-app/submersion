import 'package:equatable/equatable.dart';

/// Represents oxygen toxicity exposure during a dive.
///
/// Tracks both CNS (Central Nervous System) toxicity percentage and
/// OTU (Oxygen Tolerance Units) for pulmonary oxygen toxicity.
class O2Exposure extends Equatable {
  /// CNS% at start of dive (from previous dives/surface interval)
  final double cnsStart;

  /// CNS% at end of dive
  final double cnsEnd;

  /// OTU accumulated during this dive
  final double otu;

  /// Maximum ppO2 reached during the dive
  final double maxPpO2;

  /// Depth at which max ppO2 occurred (meters)
  final double maxPpO2Depth;

  /// Time spent above warning threshold (1.4 bar) in seconds
  final int timeAboveWarning;

  /// Time spent above critical threshold (1.6 bar) in seconds
  final int timeAboveCritical;

  const O2Exposure({
    this.cnsStart = 0.0,
    this.cnsEnd = 0.0,
    this.otu = 0.0,
    this.maxPpO2 = 0.0,
    this.maxPpO2Depth = 0.0,
    this.timeAboveWarning = 0,
    this.timeAboveCritical = 0,
  });

  /// CNS% accumulated during this dive
  double get cnsDelta => cnsEnd - cnsStart;

  /// Whether CNS is in warning zone (>80%)
  bool get cnsWarning => cnsEnd >= 80.0;

  /// Whether CNS is critical (>100%)
  bool get cnsCritical => cnsEnd >= 100.0;

  /// Whether ppO2 exceeded safe working limit (1.4 bar)
  bool get ppO2Warning => maxPpO2 > 1.4;

  /// Whether ppO2 exceeded maximum deco limit (1.6 bar)
  bool get ppO2Critical => maxPpO2 > 1.6;

  /// Daily OTU limit (typically 300 for single day, 850 cumulative)
  static const double dailyOtuLimit = 300.0;

  /// OTU as percentage of daily limit
  double get otuPercentOfDaily => (otu / dailyOtuLimit) * 100;

  /// CNS formatted as percentage string
  String get cnsFormatted => '${cnsEnd.toStringAsFixed(0)}%';

  /// OTU formatted with units
  String get otuFormatted => '${otu.toStringAsFixed(0)} OTU';

  /// Max ppO2 formatted with units
  String get maxPpO2Formatted => '${maxPpO2.toStringAsFixed(2)} bar';

  /// Create zero exposure (no O2 toxicity)
  factory O2Exposure.zero() {
    return const O2Exposure();
  }

  O2Exposure copyWith({
    double? cnsStart,
    double? cnsEnd,
    double? otu,
    double? maxPpO2,
    double? maxPpO2Depth,
    int? timeAboveWarning,
    int? timeAboveCritical,
  }) {
    return O2Exposure(
      cnsStart: cnsStart ?? this.cnsStart,
      cnsEnd: cnsEnd ?? this.cnsEnd,
      otu: otu ?? this.otu,
      maxPpO2: maxPpO2 ?? this.maxPpO2,
      maxPpO2Depth: maxPpO2Depth ?? this.maxPpO2Depth,
      timeAboveWarning: timeAboveWarning ?? this.timeAboveWarning,
      timeAboveCritical: timeAboveCritical ?? this.timeAboveCritical,
    );
  }

  @override
  List<Object?> get props => [
        cnsStart,
        cnsEnd,
        otu,
        maxPpO2,
        maxPpO2Depth,
        timeAboveWarning,
        timeAboveCritical,
      ];
}

/// NOAA CNS clock table for calculating CNS% per minute at given ppO2.
///
/// Based on NOAA Diving Manual oxygen exposure limits.
class CnsTable {
  /// Get CNS% accumulation per minute at given ppO2
  ///
  /// Returns 0 if ppO2 is below 0.5 bar (no CNS accumulation).
  /// Returns high value for ppO2 > 1.6 (immediate danger zone).
  static double cnsPerMinute(double ppO2) {
    if (ppO2 <= 0.5) return 0.0;
    if (ppO2 <= 0.6) return 100.0 / 720.0; // 720 min limit
    if (ppO2 <= 0.7) return 100.0 / 570.0; // 570 min limit
    if (ppO2 <= 0.8) return 100.0 / 450.0; // 450 min limit
    if (ppO2 <= 0.9) return 100.0 / 360.0; // 360 min limit
    if (ppO2 <= 1.0) return 100.0 / 300.0; // 300 min limit
    if (ppO2 <= 1.1) return 100.0 / 240.0; // 240 min limit
    if (ppO2 <= 1.2) return 100.0 / 210.0; // 210 min limit
    if (ppO2 <= 1.3) return 100.0 / 180.0; // 180 min limit
    if (ppO2 <= 1.4) return 100.0 / 150.0; // 150 min limit
    if (ppO2 <= 1.5) return 100.0 / 120.0; // 120 min limit
    if (ppO2 <= 1.6) return 100.0 / 45.0; // 45 min limit
    // Above 1.6 bar is extremely dangerous
    return 100.0 / 10.0; // Rapid accumulation
  }

  /// Calculate CNS% for a time segment at constant ppO2
  static double cnsForSegment(double ppO2, int durationSeconds) {
    final minutes = durationSeconds / 60.0;
    return cnsPerMinute(ppO2) * minutes;
  }

  /// Half-time for CNS recovery at surface (approximately 90 minutes)
  static const double cnsHalfTimeMinutes = 90.0;

  /// Calculate remaining CNS% after surface interval
  static double cnsAfterSurfaceInterval(
      double currentCns, int surfaceIntervalMinutes) {
    if (currentCns <= 0) return 0.0;
    // Exponential decay with 90-minute half-time
    final halfTimes = surfaceIntervalMinutes / cnsHalfTimeMinutes;
    return currentCns * (0.5 * halfTimes);
  }
}

/// OTU (Oxygen Tolerance Units) calculator.
///
/// OTU formula: t * ((ppO2 - 0.5) / 0.5)^0.833
/// where t is time in minutes and ppO2 is partial pressure in bar.
class OtuCalculator {
  /// Calculate OTU for a time segment at constant ppO2
  ///
  /// Returns 0 if ppO2 is at or below 0.5 bar (no pulmonary toxicity).
  static double otuForSegment(double ppO2, int durationSeconds) {
    if (ppO2 <= 0.5) return 0.0;

    final minutes = durationSeconds / 60.0;
    final factor = (ppO2 - 0.5) / 0.5;
    // Using the standard OTU formula with exponent ~0.833 (5/6)
    return minutes * _power(factor, 5.0 / 6.0);
  }

  /// Helper for power calculation
  static double _power(double base, double exponent) {
    if (base <= 0) return 0;
    return base.isFinite ? _exp(exponent * _ln(base)) : 0;
  }

  static double _exp(double x) {
    // Use dart:math exp
    return x.isFinite ? (2.718281828459045 * x).abs() < 700 ? _expImpl(x) : 0 : 0;
  }

  static double _expImpl(double x) {
    // Simple implementation using dart's built-in
    double result = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      result += term;
    }
    return result;
  }

  static double _ln(double x) {
    if (x <= 0) return double.negativeInfinity;
    // Natural log approximation
    double result = 0;
    double y = (x - 1) / (x + 1);
    double y2 = y * y;
    double term = y;
    for (int i = 1; i <= 50; i += 2) {
      result += term / i;
      term *= y2;
    }
    return 2 * result;
  }
}
