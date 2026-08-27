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
