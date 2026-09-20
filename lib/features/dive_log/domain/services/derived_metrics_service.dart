import 'dart:math' as math;

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/entities/derived_metrics.dart';

/// One tank's pressure over time, already decoded, with the volume needed to
/// turn a pressure drop into gas.
class TankPressureSeries {
  final String tankId;
  final double? volumeLiters;
  final List<({int timestamp, double bar})> points;

  const TankPressureSeries({
    required this.tankId,
    this.volumeLiters,
    required this.points,
  });
}

/// Derives the handful of per-dive numbers that only a profile decode can
/// answer, so the Explore filter can ask about them in SQL.
///
/// Pure: no database, no Flutter, no analysis engine. That is what lets the
/// worker isolate run it and the tests pin it with synthetic profiles.
abstract final class DerivedMetricsService {
  /// Bump whenever a rule below changes; every stored row with a lower
  /// version is rebuilt by the sweep.
  static const int version = 1;

  /// Depth under which a level run counts as a final stop.
  static const double finalStopMaxDepthMeters = 7.0;

  /// A level run must last this long to be a stop rather than a pause.
  static const int finalStopMinSeconds = 60;

  /// How far a sample may sit from a run's median and still be "level".
  static const double levelWindowMeters = 1.5;

  static bool isCurrent(DiveDerivedMetrics m, int diveUpdatedAt) =>
      m.engineVersion >= version && m.sourceUpdatedAt == diveUpdatedAt;

  static DiveDerivedMetrics compute({
    required String diveId,
    required List<ProfileSample> samples,
    required List<TankPressureSeries> tanks,
    required DiveMode diveMode,
    required int sourceUpdatedAt,
    required int computedAtMs,
  }) {
    DiveDerivedMetrics bare(UnsupportedReason reason) => DiveDerivedMetrics(
      diveId: diveId,
      engineVersion: version,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: computedAtMs,
      unsupportedReason: reason,
      runtimeSeconds: samples.isEmpty ? null : samples.last.timestamp,
    );

    // Gauge dives carry no usable gas data and their depth track is not a
    // decompression profile, so neither metric means anything.
    if (diveMode == DiveMode.gauge) return bare(UnsupportedReason.gaugeMode);
    if (samples.length < 2) return bare(UnsupportedReason.tooShort);

    final ordered = [...samples]
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final stop = _finalStop(ordered);
    final sac = _sac(ordered, tanks);

    return DiveDerivedMetrics(
      diveId: diveId,
      engineVersion: version,
      sourceUpdatedAt: sourceUpdatedAt,
      computedAt: computedAtMs,
      finalStopKind: stop?.kind ?? FinalStopKind.none,
      finalStopStartSeconds: stop?.startSeconds,
      finalStopDurationSeconds: stop?.durationSeconds,
      finalStopDepthStdDevMeters: stop?.stdDev,
      finalStopMaxExcursionMeters: stop?.maxExcursion,
      sacMeanBarPerMin: sac?.mean,
      sacSlopeBarPerMinPerMin: sac?.slope,
      runtimeSeconds: ordered.last.timestamp,
      unsupportedReason: sac == null
          ? UnsupportedReason.noPressureSeries
          : null,
      sacBuckets: sac?.buckets ?? const [],
    );
  }

  static ({
    FinalStopKind kind,
    int startSeconds,
    int durationSeconds,
    double stdDev,
    double maxExcursion,
  })?
  _finalStop(List<ProfileSample> samples) {
    // Walk backwards from the last sample shallower than the stop ceiling,
    // collecting while the depth stays inside the level window of the run's
    // running median.
    var end = samples.length - 1;
    while (end >= 0 && samples[end].depth > finalStopMaxDepthMeters) {
      end--;
    }
    if (end < 1) return null;

    // "Level" is judged on the run's SPREAD, not on each sample's distance
    // from a running median: a diver alternating above and below the median
    // moves it on every sample, which would end the run at the first swing
    // even though the whole swing sits inside the band.
    final run = <ProfileSample>[samples[end]];
    var low = run.first.depth;
    var high = run.first.depth;
    for (var i = end - 1; i >= 0; i--) {
      final candidate = samples[i];
      if (candidate.depth > finalStopMaxDepthMeters) break;
      final nextLow = math.min(low, candidate.depth);
      final nextHigh = math.max(high, candidate.depth);
      if (nextHigh - nextLow > levelWindowMeters * 2) break;
      low = nextLow;
      high = nextHigh;
      run.insert(0, candidate);
    }
    if (run.length < 2) return null;

    final duration = run.last.timestamp - run.first.timestamp;
    if (duration < finalStopMinSeconds) return null;

    final depths = run.map((s) => s.depth).toList();
    final median = _median(depths);
    final mean = depths.reduce((a, b) => a + b) / depths.length;
    final variance =
        depths.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
        depths.length;
    final excursion = depths
        .map((d) => (d - median).abs())
        .reduce((a, b) => a > b ? a : b);
    // decoType 2 is a mandatory deco stop; anything else at this depth is a
    // safety stop the diver chose.
    final isDeco = run.any((s) => s.decoType == 2);

    return (
      kind: isDeco ? FinalStopKind.deco : FinalStopKind.safety,
      startSeconds: run.first.timestamp,
      durationSeconds: duration,
      stdDev: math.sqrt(variance),
      maxExcursion: excursion,
    );
  }

  static ({List<SacBucket> buckets, double mean, double? slope})? _sac(
    List<ProfileSample> samples,
    List<TankPressureSeries> tanks,
  ) {
    final tank = _referenceTank(tanks);
    if (tank == null) return null;

    final lastTime = samples.last.timestamp;
    final buckets = <SacBucket>[];
    final midMinutes = <double>[];

    for (var index = 0; index * kSacBucketSeconds <= lastTime; index++) {
      final from = index * kSacBucketSeconds;
      final to = math.min(from + kSacBucketSeconds, lastTime);
      if (to <= from) continue;
      final startBar = _pressureAt(tank, from);
      final endBar = _pressureAt(tank, to);
      if (startBar == null || endBar == null) continue;
      final drop = startBar - endBar;
      // A non-negative drop is a tank change or a sensor glitch, not a
      // breath: recording it as zero would drag the mean and the slope.
      if (drop <= 0) continue;
      final minutes = (to - from) / 60.0;
      if (minutes <= 0) continue;
      final ata = 1 + _meanDepth(samples, from, to) / 10.0;
      if (ata <= 0) continue;
      buckets.add(SacBucket(index: index, sacBarPerMin: drop / minutes / ata));
      midMinutes.add((from + to) / 2 / 60.0);
    }

    if (buckets.isEmpty) return null;
    final values = buckets.map((b) => b.sacBarPerMin).toList();
    final mean = values.reduce((a, b) => a + b) / values.length;
    return (buckets: buckets, mean: mean, slope: _slope(midMinutes, values));
  }

  /// The tank that did the most work, which is the one the diver breathed.
  static TankPressureSeries? _referenceTank(List<TankPressureSeries> tanks) {
    TankPressureSeries? best;
    var bestDrop = 0.0;
    for (final tank in tanks) {
      if (tank.volumeLiters == null || tank.points.length < 2) continue;
      final sorted = [...tank.points]
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      final drop = sorted.first.bar - sorted.last.bar;
      if (drop > bestDrop) {
        bestDrop = drop;
        best = TankPressureSeries(
          tankId: tank.tankId,
          volumeLiters: tank.volumeLiters,
          points: sorted,
        );
      }
    }
    return best;
  }

  /// Linear interpolation between the bracketing points; null outside them.
  static double? _pressureAt(TankPressureSeries tank, int timestamp) {
    final points = tank.points;
    if (timestamp < points.first.timestamp) return null;
    if (timestamp > points.last.timestamp) return null;
    for (var i = 1; i < points.length; i++) {
      final a = points[i - 1];
      final b = points[i];
      if (timestamp <= b.timestamp) {
        final span = b.timestamp - a.timestamp;
        if (span <= 0) return b.bar;
        final f = (timestamp - a.timestamp) / span;
        return a.bar + (b.bar - a.bar) * f;
      }
    }
    return points.last.bar;
  }

  static double _meanDepth(List<ProfileSample> samples, int from, int to) {
    final inWindow = samples
        .where((s) => s.timestamp >= from && s.timestamp < to)
        .map((s) => s.depth)
        .toList();
    if (inWindow.isEmpty) return 0;
    return inWindow.reduce((a, b) => a + b) / inWindow.length;
  }

  /// Least squares. Null under two points: a single bucket has no trend, and
  /// reporting zero would read as "flat" rather than "unknown".
  static double? _slope(List<double> xs, List<double> ys) {
    if (xs.length < 2) return null;
    final n = xs.length;
    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      numerator += (xs[i] - meanX) * (ys[i] - meanY);
      denominator += (xs[i] - meanX) * (xs[i] - meanX);
    }
    if (denominator == 0) return null;
    return numerator / denominator;
  }

  static double _median(List<double> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return (sorted[mid - 1] + sorted[mid]) / 2;
  }
}
