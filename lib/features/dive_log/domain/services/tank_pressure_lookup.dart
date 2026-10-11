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

/// The pressure in bar at [timestamp], interpolated linearly between the
/// samples either side of it. Before the first sample or after the last,
/// the nearest sample's pressure. Null when [pressurePoints] is empty.
///
/// Series come from the repository in timestamp order, so the list is only
/// copied and sorted when it is not; the range panel calls this on every
/// drag frame.
double? pressureAtTime(List<TankPressurePoint> pressurePoints, int timestamp) {
  if (pressurePoints.isEmpty) return null;

  var sorted = pressurePoints;
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i].timestamp < sorted[i - 1].timestamp) {
      sorted = List<TankPressurePoint>.from(pressurePoints)
        ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
      break;
    }
  }

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
