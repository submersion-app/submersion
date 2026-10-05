import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/nav_track/domain/nav_track_point_codec.dart'
    show kMaxNavTrackPointCount;

/// The inertial route a Suunto Nautic S or Ocean records and the Suunto app
/// exports as `DiveRoute` (issue #1445): metres relative to
/// [originLatitude]/[originLongitude], the export's `DiveRouteOrigin`.
///
/// The watch itself stores only raw 10 Hz IMU data; the app dead-reckons
/// this route afterwards, so a JSON export is its only source.
class SuuntoDiveRoute {
  const SuuntoDiveRoute({
    required this.points,
    this.originLatitude,
    this.originLongitude,
  });

  final List<NavTrackPoint> points;

  /// `DiveRouteOrigin` in degrees, where east 0 / north 0 sits on the map.
  /// Null when the export carried no usable origin.
  final double? originLatitude;
  final double? originLongitude;
}

/// Reads `DiveRoute` samples into a [SuuntoDiveRoute].
///
/// Axis convention: X is east and Y is north. Z is depth, with its sign
/// calibrated from the recording itself: when most samples are negative
/// the device wrote Z up-positive and every value is negated, so depth is
/// always positive down whichever way the export writes it.
class SuuntoDiveRouteParser {
  const SuuntoDiveRouteParser._();

  /// Null when fewer than two usable points remain, or more than a track
  /// can store; the dive still imports either way.
  ///
  /// [timestampMs] reads a sample's `TimeISO8601` as wall-clock-as-UTC
  /// milliseconds, and [clockCorrection] is the shift the dive start got,
  /// so the route sits on the same time base as the dive's profile.
  static SuuntoDiveRoute? parse(
    List<Map<String, dynamic>> samples, {
    required int? Function(Map<String, dynamic> sample) timestampMs,
    required Duration clockCorrection,
    double? originLatitude,
    double? originLongitude,
  }) {
    final raw = <({int timestamp, double x, double y, double z})>[];
    int? lastTimestamp;
    for (final sample in samples) {
      final route = sample['DiveRoute'];
      if (route is! Map) continue;
      final x = _finite(route['X']);
      final y = _finite(route['Y']);
      final z = _finite(route['Z']);
      if (x == null || y == null || z == null) continue;
      final ms = timestampMs(sample);
      if (ms == null) continue;
      final timestamp = ((ms + clockCorrection.inMilliseconds) / 1000).floor();
      // A sample stamped earlier than the one before it cannot be placed on
      // the route's timeline; drop it rather than reorder the recording.
      if (lastTimestamp != null && timestamp < lastTimestamp) continue;
      lastTimestamp = timestamp;
      raw.add((timestamp: timestamp, x: x, y: y, z: z));
    }

    if (raw.length < 2 || raw.length > kMaxNavTrackPointCount) return null;

    final negatives = raw.where((r) => r.z < 0).length;
    final sign = negatives * 2 > raw.length ? -1.0 : 1.0;

    return SuuntoDiveRoute(
      points: List.unmodifiable([
        for (final r in raw)
          NavTrackPoint(
            timestamp: r.timestamp,
            north: r.y,
            east: r.x,
            depth: _depth(sign * r.z),
          ),
      ]),
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
  }

  /// Positive down; a small reading above the surface is clamped to zero.
  static double _depth(double value) => value < 0 ? 0.0 : value;

  static double? _finite(Object? value) {
    if (value is! num) return null;
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
}
