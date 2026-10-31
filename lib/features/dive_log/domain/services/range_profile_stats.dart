import 'dart:math' as math;

import 'package:submersion/core/utils/time_weighted_mean.dart';
import 'package:submersion/features/dive_log/data/services/profile_surface_lead_in.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Statistics over a selected span of a dive profile.
///
/// A null value could not be derived from the profile. It is never a depth
/// or a rate of zero, which a flat stretch at the surface reports for real.
class RangeProfileStats {
  /// The selection's own duration, however much of it the profile reaches.
  final int elapsedSeconds;

  /// Signed change in meters across the selection, positive going deeper.
  final double? depthDelta;
  final double? minDepth;
  final double? maxDepth;

  /// Time-weighted average depth in meters.
  final double? avgDepth;

  /// Depth change per minute of plotted profile, signed like [depthDelta].
  final double? avgVerticalSpeed;

  /// Steepest stretch going deeper, in m/min. Zero when the selection has
  /// none.
  final double? maxDescentRate;

  /// Steepest stretch going shallower, in m/min. Zero when the selection
  /// has none.
  final double? maxAscentRate;
  final double? minTemp;
  final double? maxTemp;
  final int? minHR;
  final int? maxHR;

  const RangeProfileStats({
    required this.elapsedSeconds,
    this.depthDelta,
    this.minDepth,
    this.maxDepth,
    this.avgDepth,
    this.avgVerticalSpeed,
    this.maxDescentRate,
    this.maxAscentRate,
    this.minTemp,
    this.maxTemp,
    this.minHR,
    this.maxHR,
  });

  bool get hasTemperature => minTemp != null;
  bool get hasHeartRate => minHR != null;
}

/// Statistics of [profile] between [startTimestamp] and [endTimestamp]
/// (seconds from the dive's start), for the profile range panel (#3890).
///
/// Depth follows the line the chart draws, not the samples that happen to
/// fall inside the selection: the line runs straight between samples, so the
/// selection's edges are interpolated onto it, and from the surface at t=0
/// where the chart draws a lead-in ([shouldDrawSurfaceLeadIn]). A selection
/// reaching past the line (a trimmed profile has none before its first
/// sample) describes the part on it, and invents no depth for the rest.
///
/// Temperature and heart rate are the readings recorded inside the selection:
/// they are logged far more sparsely than depth, often only every few samples,
/// and a range's minimum and maximum should be values the instrument gave.
RangeProfileStats rangeProfileStats({
  required List<DiveProfilePoint> profile,
  required int startTimestamp,
  required int endTimestamp,
}) {
  final recorded = profile.where(
    (p) => p.timestamp >= startTimestamp && p.timestamp <= endTimestamp,
  );
  final temperatures = recorded.map((p) => p.temperature).nonNulls.toList();
  final heartRates = recorded.map((p) => p.heartRate).nonNulls.toList();

  final line = samplesInWindow(
    shouldDrawSurfaceLeadIn(profile)
        ? [const DiveProfilePoint(timestamp: 0, depth: 0), ...profile]
        : profile,
    start: startTimestamp,
    end: endTimestamp,
    time: (p) => p.timestamp,
    value: (p) => p.depth,
  );
  final depths = line.map((s) => s.value).toList();
  final change = _depthChange(line);

  return RangeProfileStats(
    elapsedSeconds: endTimestamp - startTimestamp,
    depthDelta: change?.delta,
    minDepth: depths.isEmpty ? null : depths.reduce(math.min),
    maxDepth: depths.isEmpty ? null : depths.reduce(math.max),
    avgDepth: timeWeightedMeanOfWindow(line),
    avgVerticalSpeed: change?.avgSpeed,
    maxDescentRate: change?.maxDescentRate,
    maxAscentRate: change?.maxAscentRate,
    minTemp: temperatures.isEmpty ? null : temperatures.reduce(math.min),
    maxTemp: temperatures.isEmpty ? null : temperatures.reduce(math.max),
    minHR: heartRates.isEmpty ? null : heartRates.reduce(math.min),
    maxHR: heartRates.isEmpty ? null : heartRates.reduce(math.max),
  );
}

/// How depth changes along [line], in meters and m/min, or null when the
/// selection reaches at most one point of it: that has a depth, but no time
/// for the depth to have changed over.
({double delta, double avgSpeed, double maxDescentRate, double maxAscentRate})?
_depthChange(List<({num time, double value})> line) {
  if (line.isEmpty) return null;
  final seconds = line.last.time - line.first.time;
  if (seconds <= 0) return null;

  var maxDescentRate = 0.0;
  var maxAscentRate = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final dt = line[i + 1].time - line[i].time;
    if (dt <= 0) continue;
    final rate = (line[i + 1].value - line[i].value) / (dt / 60.0);
    maxDescentRate = math.max(maxDescentRate, rate);
    maxAscentRate = math.max(maxAscentRate, -rate);
  }

  final delta = line.last.value - line.first.value;
  return (
    delta: delta,
    avgSpeed: delta / (seconds / 60.0),
    maxDescentRate: maxDescentRate,
    maxAscentRate: maxAscentRate,
  );
}
