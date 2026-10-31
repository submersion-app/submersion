import 'dart:math' as math;

import 'package:submersion/features/dive_log/data/services/profile_surface_lead_in.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/profile_position.dart';

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
  final minTemp = temperatures.isEmpty ? null : temperatures.reduce(math.min);
  final maxTemp = temperatures.isEmpty ? null : temperatures.reduce(math.max);
  final minHR = heartRates.isEmpty ? null : heartRates.reduce(math.min);
  final maxHR = heartRates.isEmpty ? null : heartRates.reduce(math.max);
  final elapsedSeconds = endTimestamp - startTimestamp;

  final line = _selectedLine(profile, startTimestamp, endTimestamp);
  if (line.isEmpty) {
    return RangeProfileStats(
      elapsedSeconds: elapsedSeconds,
      minTemp: minTemp,
      maxTemp: maxTemp,
      minHR: minHR,
      maxHR: maxHR,
    );
  }

  final depths = line.map((p) => p.depth);
  final minDepth = depths.reduce(math.min);
  final maxDepth = depths.reduce(math.max);

  // The selection only touches the line at one point: there is a depth, but
  // no time for it to have changed over.
  final lineSeconds = line.last.timestamp - line.first.timestamp;
  if (lineSeconds <= 0) {
    return RangeProfileStats(
      elapsedSeconds: elapsedSeconds,
      minDepth: minDepth,
      maxDepth: maxDepth,
      avgDepth: line.first.depth,
      minTemp: minTemp,
      maxTemp: maxTemp,
      minHR: minHR,
      maxHR: maxHR,
    );
  }

  var depthSeconds = 0.0;
  var maxDescentRate = 0.0;
  var maxAscentRate = 0.0;
  for (var i = 0; i < line.length - 1; i++) {
    final dt = line[i + 1].timestamp - line[i].timestamp;
    if (dt <= 0) continue;
    depthSeconds += (line[i].depth + line[i + 1].depth) / 2 * dt;
    final rate = (line[i + 1].depth - line[i].depth) / (dt / 60.0); // m/min
    maxDescentRate = math.max(maxDescentRate, rate);
    maxAscentRate = math.max(maxAscentRate, -rate);
  }

  final depthDelta = line.last.depth - line.first.depth;
  return RangeProfileStats(
    elapsedSeconds: elapsedSeconds,
    depthDelta: depthDelta,
    minDepth: minDepth,
    maxDepth: maxDepth,
    avgDepth: depthSeconds / lineSeconds,
    avgVerticalSpeed: depthDelta / (lineSeconds / 60.0),
    maxDescentRate: maxDescentRate,
    maxAscentRate: maxAscentRate,
    minTemp: minTemp,
    maxTemp: maxTemp,
    minHR: minHR,
    maxHR: maxHR,
  );
}

/// The vertices of the plotted line between [start] and [end], with a vertex
/// added at each edge that falls between two samples. Empty when the
/// selection does not reach the line at all.
List<DiveProfilePoint> _selectedLine(
  List<DiveProfilePoint> profile,
  int start,
  int end,
) {
  if (profile.isEmpty) return const [];
  final plotted = shouldDrawSurfaceLeadIn(profile)
      ? [const DiveProfilePoint(timestamp: 0, depth: 0), ...profile]
      : profile;

  final from = math.max(start, plotted.first.timestamp);
  final to = math.min(end, plotted.last.timestamp);
  if (from > to) return const [];

  final inside = plotted
      .where((p) => p.timestamp >= from && p.timestamp <= to)
      .toList();
  return [
    if (inside.isEmpty || inside.first.timestamp > from)
      _pointOnLine(plotted, from),
    ...inside,
    if (inside.isEmpty || inside.last.timestamp < to) _pointOnLine(plotted, to),
  ];
}

/// The line's point at [timestamp], which must fall strictly between two of
/// its vertices: the first one past it is then later, so the span is never 0.
DiveProfilePoint _pointOnLine(List<DiveProfilePoint> plotted, int timestamp) {
  final index = indexForTimestamp(plotted, timestamp)!;
  final before = plotted[index];
  final after = plotted[index + 1];
  final fraction =
      (timestamp - before.timestamp) / (after.timestamp - before.timestamp);
  return DiveProfilePoint(
    timestamp: timestamp,
    depth: before.depth + (after.depth - before.depth) * fraction,
  );
}
