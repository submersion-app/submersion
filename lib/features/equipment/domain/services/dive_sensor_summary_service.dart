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

  /// Whether [summary] describes the dive as it is now: built by this
  /// engine version from the dive's current `updated_at` ([diveUpdatedAt]).
  /// A stale row describes an older version of the dive and must not be
  /// read until the rebuild the scheduler queues for it lands.
  static bool isCurrent(DiveSensorSummary summary, int diveUpdatedAt) =>
      summary.engineVersion >= version &&
      summary.sourceUpdatedAt == diveUpdatedAt;

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

  /// Slack for threshold comparisons: 1.1 minus 1.0 is a hair above 0.1 in
  /// binary floating point, and a reading exactly on a line must not
  /// count as beyond it.
  static const double _epsilon = 1e-9;

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

  /// One [CellMetrics] per slot that carried ppO2 on the dive, in slot
  /// order. See the class constants for every threshold.
  static List<CellMetrics> cellMetrics(List<ProfileSample> samples) {
    // Per-sample median over the slots with data, or null when fewer than
    // two slots reported, so a single-cell profile yields gain only.
    final medians = List<double?>.filled(samples.length, null);
    for (var i = 0; i < samples.length; i++) {
      final values = <double>[
        for (var slot = 1; slot <= slotCount; slot++) ?_ppO2(samples[i], slot),
      ];
      if (values.length >= 2) medians[i] = median(values);
    }

    final result = <CellMetrics>[];
    for (var slot = 1; slot <= slotCount; slot++) {
      var used = 0;
      final gains = <double>[];
      final magnitudes = <double>[];
      final lowMagnitudes = <double>[];
      var highSamples = 0;
      var lowAtHigh = 0;
      final ranges = <DivergenceRange>[];
      int? runStart;
      int? runEnd;
      var runPeak = 0.0;

      void closeRun() {
        if (runStart != null &&
            runEnd! - runStart! >= divergenceRangeMinSeconds) {
          ranges.add(
            DivergenceRange(
              startSeconds: runStart!,
              endSeconds: runEnd!,
              peakBar: runPeak,
            ),
          );
        }
        runStart = null;
        runEnd = null;
        runPeak = 0.0;
      }

      for (var i = 0; i < samples.length; i++) {
        final sample = samples[i];
        final ppO2 = _ppO2(sample, slot);
        if (ppO2 == null) {
          closeRun();
          continue;
        }
        used++;
        final mv = _mv(sample, slot);
        if (mv != null && ppO2 >= minGainPpO2Bar) gains.add(mv / ppO2);

        final medianPpO2 = medians[i];
        if (medianPpO2 == null) {
          closeRun();
          continue;
        }
        final divergence = ppO2 - medianPpO2;
        final magnitude = divergence.abs();
        magnitudes.add(magnitude);

        if (magnitude > divergenceRangeThresholdBar + _epsilon) {
          runStart ??= sample.timestamp;
          runEnd = sample.timestamp;
          if (magnitude > runPeak) runPeak = magnitude;
        } else {
          closeRun();
        }

        if (medianPpO2 <= currentLimitAgreementMaxPpO2Bar) {
          lowMagnitudes.add(magnitude);
        }
        if (medianPpO2 > currentLimitHighPpO2Bar) {
          highSamples++;
          if (divergence < -currentLimitLowByBar - _epsilon) lowAtHigh++;
        }
      }
      closeRun();
      if (used == 0) continue;

      final agreedAtLow =
          lowMagnitudes.isNotEmpty &&
          median(lowMagnitudes) <= currentLimitAgreementBar + _epsilon;
      result.add(
        CellMetrics(
          slot: slot,
          samples: used,
          gainMvPerBar: gains.isEmpty ? null : median(gains),
          p95DivergenceBar: magnitudes.isEmpty
              ? null
              : percentile(magnitudes, 0.95),
          highPpO2Samples: highSamples,
          lowAtHighFraction: agreedAtLow && highSamples > 0
              ? lowAtHigh / highSamples
              : null,
          divergenceRanges: ranges,
        ),
      );
    }
    return result;
  }

  static double? _ppO2(ProfileSample s, int slot) => switch (slot) {
    1 => s.o2Sensor1,
    2 => s.o2Sensor2,
    3 => s.o2Sensor3,
    4 => s.o2Sensor4,
    5 => s.o2Sensor5,
    6 => s.o2Sensor6,
    _ => null,
  };

  static int? _mv(ProfileSample s, int slot) => switch (slot) {
    1 => s.o2SensorMv1,
    2 => s.o2SensorMv2,
    3 => s.o2SensorMv3,
    4 => s.o2SensorMv4,
    5 => s.o2SensorMv5,
    6 => s.o2SensorMv6,
    _ => null,
  };

  /// One [TransmitterGap] per tank whose series has at least two samples.
  ///
  /// The dive spans from the earlier of the profile start and the series
  /// start to the later of their ends, so a transmitter that woke up late
  /// or died early can be charged for the span the depth series covered
  /// without it. Those two uncovered spans face the same test as an
  /// interval between readings: only one longer than
  /// [gapCadenceFactor] cadences counts. Starting a cadence or two into
  /// the dive is the first reading landing normally, not a dropout.
  static List<TransmitterGap> transmitterGaps(
    List<ProfileSample> samples,
    List<TankSensorSeries> tanks,
  ) {
    final profileStart = samples.isEmpty ? null : samples.first.timestamp;
    final profileEnd = samples.isEmpty ? null : samples.last.timestamp;
    final result = <TransmitterGap>[];
    for (final tank in tanks) {
      final series = tank.samples;
      if (series.length < 2) continue;
      final intervals = <double>[
        for (var i = 1; i < series.length; i++)
          (series[i].timestamp - series[i - 1].timestamp).toDouble(),
      ];
      final cadence = median(intervals);
      if (cadence <= 0) continue;
      final limit = cadence * gapCadenceFactor;

      var gapSeconds = 0;
      var gapCount = 0;
      var longest = 0;
      void account(int seconds) {
        if (seconds <= limit) return;
        gapSeconds += seconds;
        gapCount++;
        if (seconds > longest) longest = seconds;
      }

      for (final interval in intervals) {
        account(interval.round());
      }
      final start = profileStart == null
          ? series.first.timestamp
          : math.min(profileStart, series.first.timestamp);
      final end = profileEnd == null
          ? series.last.timestamp
          : math.max(profileEnd, series.last.timestamp);
      account(series.first.timestamp - start);
      account(end - series.last.timestamp);

      result.add(
        TransmitterGap(
          tankId: tank.tankId,
          transmitterSerial: tank.transmitterSerial,
          computerId: tank.computerId,
          cadenceSeconds: cadence,
          gapSeconds: gapSeconds,
          gapCount: gapCount,
          longestGapSeconds: longest,
          diveSeconds: end - start,
        ),
      );
    }
    return result;
  }

  /// Median of a non-empty list. Even counts average the middle pair.
  static double median(List<double> values) {
    assert(values.isNotEmpty, 'median of nothing');
    final sorted = List<double>.of(values)..sort();
    final mid = sorted.length ~/ 2;
    return sorted.length.isOdd
        ? sorted[mid]
        : (sorted[mid - 1] + sorted[mid]) / 2;
  }

  /// Nearest-rank percentile of a non-empty list, [fraction] in 0 to 1:
  /// the value at rank `ceil(fraction * n)` counting from one, which is
  /// the smallest value with at least that share of the data at or below
  /// it. No interpolation, so the figure is always a reading that was
  /// actually taken.
  ///
  /// The epsilon keeps an exact product on its own rank: `0.4 * 5` can
  /// land a hair above 2 in binary floating point, and a bare ceiling
  /// would then step to the next reading.
  static double percentile(List<double> values, double fraction) {
    assert(values.isNotEmpty, 'percentile of nothing');
    final sorted = List<double>.of(values)..sort();
    final rank = (fraction * sorted.length - _epsilon).ceil();
    return sorted[math.max(0, math.min(sorted.length - 1, rank - 1))];
  }
}
