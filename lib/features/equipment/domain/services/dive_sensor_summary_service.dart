import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/tank_pressure_series_codec.dart';
import 'package:submersion/features/equipment/domain/entities/dive_sensor_summary.dart';

/// One tank's pressure series with the identity the gap rules key on.
class TankSensorSeries {
  final String tankId;
  final String? transmitterSerial;
  final String? computerId;

  /// Sorted by timestamp, as the repository stores them.
  final List<TankPressureSample> samples;

  const TankSensorSeries({
    required this.tankId,
    this.transmitterSerial,
    this.computerId,
    required this.samples,
  });
}

/// Pure: decoded samples in, one [DiveSensorSummary] out. Runs on the
/// worker isolate through `computeSensorSummaryFromBlobs`, so it must not
/// touch Flutter, the database or any provider.
///
/// Bump [version] whenever a rule here changes what a stored row would
/// contain; the repository recomputes every row whose version is older.
class DiveSensorSummaryService {
  static const int version = 1;

  /// Cells report `o2Sensor1` to `o2Sensor6`.
  static const int slotCount = 6;

  /// Gain samples below this ppO2 are skipped: the reading is dominated by
  /// offset and noise, not the cell's output.
  static const double minGainPpO2Bar = 0.2;

  /// A slot more than this far from the median of its peers is diverging.
  static const double divergenceRangeThresholdBar = 0.1;

  /// A divergence run shorter than this is not stored as a range.
  static const int divergenceRangeMinSeconds = 30;

  /// Current limiting is judged over samples above this median ppO2.
  static const double currentLimitHighPpO2Bar = 1.2;

  /// A slot reading more than this below the median at high ppO2 counts as
  /// limited on that sample.
  static const double currentLimitLowByBar = 0.1;

  /// The slot must have tracked its peers within this at low ppO2 on the
  /// same dive, or the limiting figure is not computed at all.
  static const double currentLimitAgreementBar = 0.05;
  static const double currentLimitAgreementMaxPpO2Bar = 1.0;

  /// An interval longer than this many cadences is a transmitter gap.
  static const int gapCadenceFactor = 3;

  const DiveSensorSummaryService();

  DiveSensorSummary summarize({
    required String diveId,
    required List<ProfileSample> samples,
    List<TankSensorSeries> tanks = const [],
    DiveMode diveMode = DiveMode.oc,
    int? runtimeSeconds,
    int? scrubberDurationMinutes,
    int? scrubberRemainingMinutes,
    required int sourceUpdatedAt,
    required DateTime computedAt,
  }) {
    double? minTemperature;
    double? maxDepth;
    for (final sample in samples) {
      final temperature = sample.temperature;
      if (temperature != null &&
          (minTemperature == null || temperature < minTemperature)) {
        minTemperature = temperature;
      }
      if (maxDepth == null || sample.depth > maxDepth) {
        maxDepth = sample.depth;
      }
    }
    return DiveSensorSummary(
      diveId: diveId,
      engineVersion: version,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: computedAt,
      minTemperature: minTemperature,
      maxDepth: maxDepth,
      scrubberConsumedMinutes: scrubberConsumedMinutes(
        diveMode: diveMode,
        runtimeSeconds: runtimeSeconds,
        durationMinutes: scrubberDurationMinutes,
        remainingMinutes: scrubberRemainingMinutes,
      ),
      cellMetrics: cellMetrics(samples),
      transmitterGaps: transmitterGaps(samples, tanks),
    );
  }

  /// Rated minus remaining when the dive carries both and the difference is
  /// not negative; else runtime minutes on the loop (CCR or SCR); else null,
  /// so an open-circuit dive never charges a scrubber.
  static double? scrubberConsumedMinutes({
    required DiveMode diveMode,
    int? runtimeSeconds,
    int? durationMinutes,
    int? remainingMinutes,
  }) {
    if (durationMinutes != null && remainingMinutes != null) {
      final consumed = durationMinutes - remainingMinutes;
      if (consumed >= 0) return consumed.toDouble();
    }
    final onLoop = diveMode == DiveMode.ccr || diveMode == DiveMode.scr;
    if (onLoop && runtimeSeconds != null && runtimeSeconds > 0) {
      return runtimeSeconds / 60.0;
    }
    return null;
  }

  /// Task 3 fills this in.
  static List<CellMetrics> cellMetrics(List<ProfileSample> samples) => const [];

  /// Task 4 fills this in.
  static List<TransmitterGap> transmitterGaps(
    List<ProfileSample> samples,
    List<TankSensorSeries> tanks,
  ) => const [];

  /// Median of a non-empty list. Even counts average the middle pair.
  static double median(List<double> values) {
    assert(values.isNotEmpty, 'median of nothing');
    final sorted = List<double>.of(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Nearest-rank percentile of a non-empty list, [fraction] in 0 to 1.
  static double percentile(List<double> values, double fraction) {
    assert(values.isNotEmpty, 'percentile of nothing');
    final sorted = List<double>.of(values)..sort();
    final index = (fraction * (sorted.length - 1)).round();
    return sorted[math.max(0, math.min(sorted.length - 1, index))];
  }
}
