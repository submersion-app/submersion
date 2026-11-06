import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';

/// [points] moved so the first sample of the dive sits at north 0, east 0.
///
/// A console reports every row as metres from its own origin, and that
/// origin is not always where the dive began. A Seacraft ENC holding a dive
/// plan counts from the plan's first point, even when the plan belongs to a
/// different site: one real recording started 36.5 km north of its own
/// origin (issue #4231). Every map layer draws a sample at the anchor plus
/// its offset, so without this the whole route lands that far from the
/// site it was dived at.
///
/// The reference is the start of [NavTrackCorrector.activeRange], not the
/// first row: a pre-dive GPS calibration sits before the dive, and the
/// anchor stands for where the dive itself began. Every sample shifts by
/// the same amount, so step lengths, fix events and the active range stay
/// exactly as they were. Returns a new list and leaves [points] untouched.
List<NavTrackPoint> rebaseOnActiveStart(List<NavTrackPoint> points) {
  if (points.isEmpty) return points;
  final start = points[NavTrackCorrector.activeRange(points).start];
  final north = start.north;
  final east = start.east;
  if (north == 0 && east == 0) return points;
  return List.unmodifiable([
    for (final p in points)
      p.copyWith(north: p.north - north, east: p.east - east),
  ]);
}
