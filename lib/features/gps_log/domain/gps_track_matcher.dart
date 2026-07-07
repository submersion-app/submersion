import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

typedef TrackPosition = ({double latitude, double longitude});

/// Pure timestamp-to-position lookup within recorded GPS tracks.
/// All timestamps are wall-clock-as-UTC (points: seconds; tracks: ms).
class GpsTrackMatcher {
  /// Maximum distance in time between a dive timestamp and the nearest
  /// usable track point (spec: 30 minutes).
  static const int toleranceSeconds = 1800;

  /// Finds the first completed track whose recording window (extended by
  /// the tolerance on both sides) contains [wallClockMs].
  static GpsTrack? trackCovering(List<GpsTrack> tracks, int wallClockMs) {
    const tolMs = toleranceSeconds * 1000;
    for (final track in tracks) {
      final end = track.endTime;
      if (end == null) continue;
      if (wallClockMs >= track.startTime - tolMs &&
          wallClockMs <= end + tolMs) {
        return track;
      }
    }
    return null;
  }

  /// Position along the track at [wallClockSeconds]: linear interpolation
  /// between the bracketing points, clamped to the nearest edge point when
  /// the time falls just outside the track (within the tolerance).
  static TrackPosition? positionAt(
    List<GpsTrackPoint> points,
    int wallClockSeconds,
  ) {
    if (points.isEmpty) return null;
    final t = wallClockSeconds;
    final first = points.first;
    final last = points.last;

    if (t <= first.timestamp) {
      return (first.timestamp - t) <= toleranceSeconds
          ? (latitude: first.latitude, longitude: first.longitude)
          : null;
    }
    if (t >= last.timestamp) {
      return (t - last.timestamp) <= toleranceSeconds
          ? (latitude: last.latitude, longitude: last.longitude)
          : null;
    }
    for (var i = 0; i < points.length - 1; i++) {
      final a = points[i];
      final b = points[i + 1];
      if (t < a.timestamp || t > b.timestamp) continue;
      final gap = b.timestamp - a.timestamp;
      if (gap > 2 * toleranceSeconds) {
        // Interior hole (interrupted recording): interpolating across it
        // would invent a mid-transit position. Clamp to the nearest edge if
        // within tolerance, else no match.
        if (t - a.timestamp <= toleranceSeconds) {
          return (latitude: a.latitude, longitude: a.longitude);
        }
        if (b.timestamp - t <= toleranceSeconds) {
          return (latitude: b.latitude, longitude: b.longitude);
        }
        return null;
      }
      if (gap == 0) return (latitude: a.latitude, longitude: a.longitude);
      final f = (t - a.timestamp) / gap;
      return (
        latitude: a.latitude + (b.latitude - a.latitude) * f,
        longitude: a.longitude + (b.longitude - a.longitude) * f,
      );
    }
    return null;
  }
}
