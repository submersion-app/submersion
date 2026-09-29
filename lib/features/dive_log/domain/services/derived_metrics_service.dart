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
  static const int version = 2;

  /// Depth under which a level run counts as a final stop.
  static const double finalStopMaxDepthMeters = 7.0;

  /// A level run must last this long to be a stop rather than a pause.
  static const int finalStopMinSeconds = 60;

  /// How far a sample may sit from the stop depth and still be at the stop.
  static const double levelWindowMeters = 1.5;

  /// Shallower than this is the end of the ascent or the surface, not a
  /// stop.
  static const double finalStopMinDepthMeters = 2.0;

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
    // A rebreather's bottles do not drain with the diver's breathing, so
    // their pressure drop is not a SAC; the depth track is still read.
    final rebreather = diveMode == DiveMode.ccr || diveMode == DiveMode.scr;
    final sac = rebreather ? null : _sac(ordered, tanks);

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
      sacChangePercent: sac?.change,
      runtimeSeconds: ordered.last.timestamp,
      unsupportedReason: rebreather
          ? UnsupportedReason.rebreather
          : sac == null
          ? UnsupportedReason.noPressureSeries
          : null,
      sacBuckets: sac?.buckets ?? const [],
    );
  }

  /// The last stop of the dive, judged the way a diver would read the
  /// profile. Only the shallow tail counts: everything after the last sample
  /// deeper than [finalStopMaxDepthMeters]. Samples shallower than
  /// [finalStopMinDepthMeters] are the ascent's end and the surface, never
  /// the stop. The stop sits at the tail's mean depth (a median snaps to one
  /// side of a diver swinging above and below it), and is the longest
  /// unbroken run of samples within [levelWindowMeters] of it.
  ///
  /// Transit is trimmed from both ends: a sample that keeps moving towards
  /// the stop on the way in, or away from it on the ascent, is not the stop.
  /// A diver swinging back and forth is never trimmed. Stability is then the
  /// 90th percentile of the distance from the stop's mean depth, so a stop is
  /// unsteady only when the diver spends real time away from it.
  static ({
    FinalStopKind kind,
    int startSeconds,
    int durationSeconds,
    double stdDev,
    double maxExcursion,
  })?
  _finalStop(List<ProfileSample> samples) {
    final lastDeep = samples.lastIndexWhere(
      (s) => s.depth > finalStopMaxDepthMeters,
    );
    if (lastDeep < 0) return null;
    final tail = samples.sublist(lastDeep + 1);
    final candidates = [
      for (final s in tail)
        if (s.depth >= finalStopMinDepthMeters) s.depth,
    ];
    if (candidates.isEmpty) return null;
    final center = candidates.reduce((a, b) => a + b) / candidates.length;

    List<ProfileSample>? best;
    var run = <ProfileSample>[];
    int span(List<ProfileSample> r) =>
        r.isEmpty ? 0 : r.last.timestamp - r.first.timestamp;
    void close() {
      if (run.length >= 2 && span(run) > span(best ?? const [])) best = run;
      run = <ProfileSample>[];
    }

    for (final s in tail) {
      final level =
          s.depth >= finalStopMinDepthMeters &&
          (s.depth - center).abs() <= levelWindowMeters;
      if (level) {
        run.add(s);
      } else {
        close();
      }
    }
    close();
    final found = best;
    if (found == null) return null;
    final stop = _trimTransit(found);
    final duration = span(stop);
    if (duration < finalStopMinSeconds) return null;

    final depths = stop.map((s) => s.depth).toList();
    final mean = depths.reduce((a, b) => a + b) / depths.length;
    final variance =
        depths.map((d) => (d - mean) * (d - mean)).reduce((a, b) => a + b) /
        depths.length;
    final excursions = depths.map((d) => (d - mean).abs()).toList()..sort();
    // Nearest-rank 90th percentile.
    final p90 =
        excursions[((excursions.length * 0.9).ceil() - 1).clamp(
          0,
          excursions.length - 1,
        )];
    // decoType 2 is a mandatory deco stop; anything else at this depth is a
    // safety stop the diver chose.
    final isDeco = stop.any((s) => s.decoType == 2);

    return (
      kind: isDeco ? FinalStopKind.deco : FinalStopKind.safety,
      startSeconds: stop.first.timestamp,
      durationSeconds: duration,
      stdDev: math.sqrt(variance),
      maxExcursion: p90,
    );
  }

  /// A run without the samples still arriving at the stop or already
  /// leaving it: from each end, drop a sample more than half a metre off the
  /// run's mean while its neighbour is closer to the mean.
  static List<ProfileSample> _trimTransit(List<ProfileSample> run) {
    final mean = run.map((s) => s.depth).reduce((a, b) => a + b) / run.length;
    double off(ProfileSample s) => (s.depth - mean).abs();
    var from = 0;
    var to = run.length - 1;
    while (to - from > 1 &&
        off(run[from]) > 0.5 &&
        off(run[from + 1]) < off(run[from])) {
      from++;
    }
    while (to - from > 1 &&
        off(run[to]) > 0.5 &&
        off(run[to - 1]) < off(run[to])) {
      to--;
    }
    return run.sublist(from, to + 1);
  }

  static ({
    List<SacBucket> buckets,
    double mean,
    double? slope,
    double? change,
  })?
  _sac(List<ProfileSample> samples, List<TankPressureSeries> tanks) {
    final tank = _referenceTank(tanks);
    if (tank == null) return null;

    final lastTime = samples.last.timestamp;
    final buckets = <SacBucket>[];
    final midMinutes = <double>[];

    for (var index = 0; index * kSacBucketSeconds <= lastTime; index++) {
      final from = index * kSacBucketSeconds;
      final to = math.min(from + kSacBucketSeconds, lastTime);
      // A slice under half a bucket (the last seconds before surfacing,
      // often at one atmosphere) would weigh as much as five minutes at
      // depth in the mean, the slope and the change.
      if (to - from < kSacBucketSeconds ~/ 2) continue;
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
    return (
      buckets: buckets,
      mean: mean,
      slope: _slope(midMinutes, values),
      change: _change(midMinutes, values, lastTime / 2 / 60.0),
    );
  }

  /// Percent change of the mean SAC after [halfMinutes] against before it.
  /// Null unless both halves have a bucket: one side alone is not a change.
  static double? _change(
    List<double> midMinutes,
    List<double> values,
    double halfMinutes,
  ) {
    final early = <double>[];
    final late = <double>[];
    for (var i = 0; i < values.length; i++) {
      (midMinutes[i] < halfMinutes ? early : late).add(values[i]);
    }
    if (early.isEmpty || late.isEmpty) return null;
    final before = early.reduce((a, b) => a + b) / early.length;
    final after = late.reduce((a, b) => a + b) / late.length;
    if (before <= 0) return null;
    return (after - before) / before * 100;
  }

  /// The tank that did the most work, which is the one the diver breathed.
  static TankPressureSeries? _referenceTank(List<TankPressureSeries> tanks) {
    TankPressureSeries? best;
    var bestDrop = 0.0;
    for (final tank in tanks) {
      // No volume needed: SAC here is pressure per minute, and many
      // imported cylinders never get a size.
      if (tank.points.length < 2) continue;
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
}
