import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_geometry.dart';

/// How a track polyline is colorized.
enum TrackColorMode { uniform, speed, elapsed }

/// Default number of quantization buckets.
///
/// flutter_map's Polyline.gradientColors cannot express a colour ramp along
/// arc length (it paints a straight screen-space gradient between the first
/// and last point), so colorization is done by quantizing into buckets and
/// emitting one Polyline per contiguous same-bucket run. Discrete bands also
/// map one-to-one onto legend rows.
const int kTrackColorBuckets = 8;

/// A contiguous span of track points sharing one quantization bucket.
class TrackRun {
  final List<GpsTrackPoint> points;
  final int bucket;

  const TrackRun({required this.points, required this.bucket});
}

/// Minimum and maximum leg speed in metres per second, or null when the
/// track has fewer than two points.
({double min, double max})? speedRange(List<GpsTrackPoint> points) {
  if (points.length < 2) return null;
  var min = double.infinity;
  var max = double.negativeInfinity;
  for (var i = 1; i < points.length; i++) {
    final speed = speedMpsBetween(points[i - 1], points[i]);
    if (speed < min) min = speed;
    if (speed > max) max = speed;
  }
  return (min: min, max: max);
}

/// Bucket index for [value] within [min]..[max], clamped to 0..buckets-1.
int _bucketFor(double value, double min, double max, int buckets) {
  if (max <= min) return 0;
  final normalized = (value - min) / (max - min);
  return (normalized * buckets).floor().clamp(0, buckets - 1);
}

/// Splits [points] into contiguous runs sharing a quantization bucket.
///
/// Consecutive runs SHARE their boundary point: run N ends on the same point
/// run N+1 begins on. Without that overlap the rendered polyline shows a
/// one-segment gap at every bucket change.
List<TrackRun> bucketizeTrack(
  List<GpsTrackPoint> points,
  TrackColorMode mode, {
  int buckets = kTrackColorBuckets,
}) {
  // A single point has no segment to draw.
  if (points.length < 2) return const [];

  if (mode == TrackColorMode.uniform) {
    return [TrackRun(points: List.unmodifiable(points), bucket: 0)];
  }

  // One bucket per LEG (there are points.length - 1 legs).
  final legBuckets = <int>[];
  if (mode == TrackColorMode.speed) {
    final range = speedRange(points);
    final min = range?.min ?? 0.0;
    final max = range?.max ?? 0.0;
    for (var i = 1; i < points.length; i++) {
      legBuckets.add(
        _bucketFor(
          speedMpsBetween(points[i - 1], points[i]),
          min,
          max,
          buckets,
        ),
      );
    }
  } else {
    final start = points.first.timestamp;
    final end = points.last.timestamp;
    for (var i = 1; i < points.length; i++) {
      legBuckets.add(
        _bucketFor(
          points[i].timestamp.toDouble(),
          start.toDouble(),
          end.toDouble(),
          buckets,
        ),
      );
    }
  }

  final runs = <TrackRun>[];
  var runStart = 0;
  for (var leg = 1; leg <= legBuckets.length; leg++) {
    final atEnd = leg == legBuckets.length;
    final bucketChanged = !atEnd && legBuckets[leg] != legBuckets[leg - 1];
    if (atEnd || bucketChanged) {
      runs.add(
        TrackRun(
          // leg L spans points[L] .. points[L+1], so a run covering legs
          // runStart..leg-1 spans points runStart .. leg inclusive.
          points: List.unmodifiable(points.sublist(runStart, leg + 1)),
          bucket: legBuckets[runStart],
        ),
      );
      runStart = leg;
    }
  }

  return List.unmodifiable(runs);
}
