import 'dart:math' as math;

import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Index of the profile sample nearest to [timestamp] without going past it.
///
/// Binary search over sample timestamps. Clamps to the first/last sample for
/// out-of-range values. Returns null for an empty profile.
int? indexForTimestamp(List<DiveProfilePoint> profile, int timestamp) {
  if (profile.isEmpty) return null;
  if (timestamp <= profile.first.timestamp) return 0;
  if (timestamp >= profile.last.timestamp) return profile.length - 1;

  var low = 0;
  var high = profile.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (profile[mid].timestamp <= timestamp) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return low;
}

/// The lowest and highest pressure reading across every tank's samples, or
/// null if none of them have any (an empty map, or tanks with empty point
/// lists).
({double min, double max})? tankPressureRange(
  Map<String, List<TankPressurePoint>> tankPressures,
) {
  final pressures = tankPressures.values
      .expand((points) => points)
      .map((p) => p.pressure);
  if (pressures.isEmpty) return null;
  return (min: pressures.reduce(math.min), max: pressures.reduce(math.max));
}

/// The scale every tank pressure reading is drawn against: [tankPressureRange]
/// with 5% padding on each side. The tank lines, their threshold markers and
/// the right axis all read it, so they cannot disagree.
///
/// Null when there is nothing to plot. A zero span means every sample across
/// every tank is identical, in practice a computer that logged a pressure
/// channel with no transmitter paired (all zeros). Mapping a constant value
/// through a zero-width range yields NaN spot coordinates that crash
/// fl_chart's touch/tooltip painter (Offset NaN).
({double min, double max})? tankPressureScale(
  Map<String, List<TankPressurePoint>> tankPressures,
) {
  final range = tankPressureRange(tankPressures);
  if (range == null) return null;
  final span = range.max - range.min;
  if (span <= 0) return null;
  return (min: range.min - span * 0.05, max: range.max + span * 0.05);
}

/// Pressure of the nearest tank sample at or before [timestamp], in bar.
///
/// Returns null if [points] is empty. Values before the first sample return
/// the first sample's pressure (tank starts full at its first reading).
double? pressureAtTimestamp(List<TankPressurePoint> points, int timestamp) {
  if (points.isEmpty) return null;
  if (timestamp <= points.first.timestamp) return points.first.pressure;
  if (timestamp >= points.last.timestamp) return points.last.pressure;

  var low = 0;
  var high = points.length - 1;
  while (low < high) {
    final mid = (low + high + 1) ~/ 2;
    if (points[mid].timestamp <= timestamp) {
      low = mid;
    } else {
      high = mid - 1;
    }
  }
  return points[low].pressure;
}
