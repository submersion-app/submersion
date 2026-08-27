import 'package:submersion/features/data_quality/domain/quality_thresholds.dart';

/// Predicates shared by the detectors (which decide WHICH repair a finding is
/// offered) and ProfileRepairService (which performs it).
///
/// One definition keeps the detect -> repair -> rescan loop convergent.
/// `QualityFindingsRepository.applyScanResults` reopens a `resolved` finding
/// that the next scan still produces, so offering a repair whose math cannot
/// clear the flagged condition makes the button look dead: the row leaves and
/// comes straight back.
abstract final class RepairPredicates {
  /// A depth outlier that neighbor interpolation removes: the sample deviates
  /// past the spike rate in both directions with opposite signs.
  static bool isDepthSpike({
    required int dt1,
    required int dt2,
    required double d0,
    required double d1,
    required double d2,
  }) {
    if (dt1 <= 0 || dt2 <= 0) return false;
    final r1 = (d1 - d0) / dt1;
    final r2 = (d2 - d1) / dt2;
    return r1.abs() > QualityThresholds.spikeRateMetersPerSecond &&
        r2.abs() > QualityThresholds.spikeRateMetersPerSecond &&
        r1.sign != r2.sign;
  }

  /// A temperature outlier that neighbor interpolation removes. The sample
  /// must deviate in both directions AND the interpolated value -- the mean of
  /// its neighbors -- must land within the per-sample limit of both of them,
  /// otherwise the smoothed series still trips the detector.
  ///
  /// A one-sided step (the reading jumps and stays there) fails this test on
  /// purpose: which side is correct is a judgment call, not mechanics.
  static bool isTemperatureSpike(double? a, double? b, double? c) {
    if (a == null || b == null || c == null) return false;
    final d1 = b - a;
    final d2 = c - b;
    if (d1.abs() <= QualityThresholds.tempJumpPerSampleC ||
        d2.abs() <= QualityThresholds.tempJumpPerSampleC ||
        d1.sign == d2.sign) {
      return false;
    }
    return (c - a).abs() / 2 <= QualityThresholds.tempJumpPerSampleC;
  }

  /// Reinterpret a reading stored as Celsius on the scale it was really
  /// recorded on. The single definition behind both the plausibility test
  /// and the conversion repairs, so what is checked is what is applied.
  static double convertToCelsius(double t, {required bool kelvinScale}) =>
      kelvinScale ? t - 273.15 : (t - 32) * 5 / 9;

  /// Whether reinterpreting a whole temperature channel on another scale
  /// lands every reading inside the plausible water-temperature range. Only
  /// then is a unit conversion the explanation for an out-of-range channel --
  /// converting because of one bad sample corrupts every good one.
  static bool convertedChannelIsPlausible(
    Iterable<double> temps, {
    required bool kelvinScale,
  }) {
    if (temps.isEmpty) return false;
    for (final t in temps) {
      final c = convertToCelsius(t, kelvinScale: kelvinScale);
      if (c < QualityThresholds.waterTempMinC ||
          c > QualityThresholds.waterTempMaxC) {
        return false;
      }
    }
    return true;
  }

  /// Whether the interior of an impossible-rate run can be replaced by a
  /// straight line between its endpoints without the run still reading as
  /// impossible. Oscillating garbage collapses to a plausible rate; a genuine
  /// sustained descent does not, and is left alone.
  static bool impossibleRunIsInterpolatable({
    required int sampleCount,
    required int startSeconds,
    required int endSeconds,
    required double startDepth,
    required double endDepth,
  }) {
    if (sampleCount < 3) return false; // no interior to redraw
    final span = endSeconds - startSeconds;
    if (span <= 0) return false;
    final rate = (endDepth - startDepth).abs() / span * 60;
    return rate <= QualityThresholds.impossibleRateMetersPerMinute;
  }

  /// A hole short enough for [fillGaps] to interpolate across.
  static bool gapIsFillable(int gapSeconds, double threshold) =>
      gapSeconds > threshold &&
      gapSeconds <= QualityThresholds.gapFillMaxSeconds;
}
