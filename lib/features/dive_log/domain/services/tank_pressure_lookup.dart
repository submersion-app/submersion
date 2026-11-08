import 'package:collection/collection.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

/// Map each tank to its time-series pressure, tolerating a re-keyed series.
///
/// A dive's transmitter pressure is stored in `tank_pressure_series` keyed
/// by tank id. A reparse, re-import, or multi-computer consolidation can
/// regenerate the dive's tanks with fresh UUIDs while the pressure rows keep
/// the old tank id (issue #276). The overall SAC curve already tolerates this
/// (`combineMultiTankPressures`); this does the same for per-cylinder SAC so
/// it does not silently go blank on those dives (issue #510).
///
/// Exact id matches win. Any remaining series whose key matches no current
/// tank ("orphaned") is adopted by a still-unmatched tank so the
/// single-transmitter case (one tank, one orphaned series) is always
/// resolved and multi-tank is a stable best effort.
///
/// Both sides are sorted with a full tie-breaker so the pairing is
/// deterministic regardless of map insertion order or tanks sharing the same
/// [DiveTank.order] (the default is 0): orphaned series by earliest sample
/// then key; unmatched tanks by order then id. This mirrors the v102 data
/// migration exactly, so the runtime result and the healed data agree.
Map<String, List<TankPressurePoint>> resolveTankPressureSeries(
  List<DiveTank> tanks,
  Map<String, List<TankPressurePoint>>? tankPressures,
) {
  final resolved = <String, List<TankPressurePoint>>{};
  if (tankPressures == null || tankPressures.isEmpty) return resolved;

  final tankIds = {for (final t in tanks) t.id};

  for (final tank in tanks) {
    final series = tankPressures[tank.id];
    if (series != null) resolved[tank.id] = series;
  }

  final orphanEntries =
      [
        for (final entry in tankPressures.entries)
          if (!tankIds.contains(entry.key)) entry,
      ]..sort((a, b) {
        final aFirst = a.value.isEmpty ? 0 : a.value.first.timestamp;
        final bFirst = b.value.isEmpty ? 0 : b.value.first.timestamp;
        final byTime = aFirst.compareTo(bFirst);
        return byTime != 0 ? byTime : a.key.compareTo(b.key);
      });
  if (orphanEntries.isEmpty) return resolved;

  final unmatchedTanks =
      [
        for (final tank in tanks)
          if (!resolved.containsKey(tank.id)) tank,
      ]..sort((a, b) {
        final byOrder = a.order.compareTo(b.order);
        return byOrder != 0 ? byOrder : a.id.compareTo(b.id);
      });

  for (var i = 0; i < unmatchedTanks.length && i < orphanEntries.length; i++) {
    resolved[unmatchedTanks[i].id] = orphanEntries[i].value;
  }

  return resolved;
}

/// [tank]'s start and end pressures in bar: the stored value, else the first
/// or last reading of [points]. A negative reading is a sensor or entry error,
/// never a pressure, so it counts as missing.
(double?, double?) resolvedTankPressures(
  DiveTank tank,
  List<TankPressurePoint>? points,
) {
  double? valid(double? pressure) =>
      pressure != null && pressure >= 0 ? pressure : null;
  final start = valid(tank.startPressure);
  final end = valid(tank.endPressure);
  if (points != null && points.isNotEmpty) {
    return (
      start ?? valid(points.first.pressure),
      end ?? valid(points.last.pressure),
    );
  }
  return (start, end);
}

/// The pressure in bar at [timestamp], interpolated linearly between the
/// samples either side of it. Before the first sample or after the last,
/// the nearest sample's pressure. Null when [pressurePoints] is empty.
///
/// Series come from the repository in timestamp order, so the list is only
/// copied and sorted when it is not; the range panel calls this on every
/// drag frame.
double? pressureAtTime(List<TankPressurePoint> pressurePoints, int timestamp) {
  if (pressurePoints.isEmpty) return null;

  final sorted = _inTimestampOrder(pressurePoints);

  // First sample at or after [timestamp]: an exact match (the first of
  // any that share the timestamp), else the sample after it.
  var low = 0;
  var high = sorted.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (sorted[mid].timestamp < timestamp) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  if (low == sorted.length) return sorted.last.pressure;
  final after = sorted[low];
  if (after.timestamp == timestamp || low == 0) return after.pressure;

  final before = sorted[low - 1];
  final ratio =
      (timestamp - before.timestamp) / (after.timestamp - before.timestamp);
  return before.pressure + (after.pressure - before.pressure) * ratio;
}

/// The pressure in bar the profile chart reads at [timestamp] for its line
/// and tooltip, so anything following the chart's cursor shows the same
/// value. Where samples share a timestamp the last of them wins, and
/// between timestamps it interpolates from the last sample before to the
/// first sample after. [pressureAtTime] differs only there: it takes the
/// first of samples sharing [timestamp]. Before the first sample or after
/// the last, the nearest sample's pressure. Null when [pressurePoints] is
/// empty.
double? pressureAtCursor(
  List<TankPressurePoint> pressurePoints,
  int timestamp,
) {
  if (pressurePoints.isEmpty) return null;

  final sorted = _inTimestampOrder(pressurePoints);

  // First sample after [timestamp]; the one before it is the last sample
  // at or before [timestamp].
  var low = 0;
  var high = sorted.length;
  while (low < high) {
    final mid = (low + high) >> 1;
    if (sorted[mid].timestamp <= timestamp) {
      low = mid + 1;
    } else {
      high = mid;
    }
  }
  if (low == 0) return sorted.first.pressure;
  final before = sorted[low - 1];
  if (low == sorted.length || before.timestamp == timestamp) {
    return before.pressure;
  }

  final after = sorted[low];
  final ratio =
      (timestamp - before.timestamp) / (after.timestamp - before.timestamp);
  return before.pressure + (after.pressure - before.pressure) * ratio;
}

/// [points] itself when already in timestamp order (as the repository
/// returns series), else a sorted copy. `mergeSort` is stable, unlike
/// `List.sort`, so samples that share a timestamp keep their order.
List<TankPressurePoint> _inTimestampOrder(List<TankPressurePoint> points) {
  for (var i = 1; i < points.length; i++) {
    if (points[i].timestamp < points[i - 1].timestamp) {
      final sorted = List<TankPressurePoint>.of(points);
      mergeSort(sorted, compare: (a, b) => a.timestamp.compareTo(b.timestamp));
      return sorted;
    }
  }
  return points;
}
