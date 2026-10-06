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
/// Axis convention, checked against three real Nautic S exports (#1445):
/// the route is east/north/up, so X is east and Y is north. Z is up
/// (negative underwater) but is not the dive's depth: it reads about
/// 1.024 x depth + 0.35 m, as if computed for fresh water. Each point's
/// depth therefore comes from the export's own `Depth` channel,
/// interpolated to the route sample's time, so the route sits exactly on
/// the dive's profile; -Z is only the fallback for an export without one.
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
    final depths = <({int ms, double depth})>[];
    final raw = <({int ms, int timestamp, double x, double y, double z})>[];
    int? lastTimestamp;
    for (final sample in samples) {
      final depth = _finite(sample['Depth']);
      if (depth != null) {
        final ms = timestampMs(sample);
        if (ms != null) depths.add((ms: ms, depth: depth));
      }
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
      raw.add((ms: ms, timestamp: timestamp, x: x, y: y, z: z));
    }

    if (raw.length < 2 || raw.length > kMaxNavTrackPointCount) return null;

    depths.sort((a, b) => a.ms.compareTo(b.ms));

    return SuuntoDiveRoute(
      points: List.unmodifiable([
        for (final r in raw)
          NavTrackPoint(
            timestamp: r.timestamp,
            north: r.y,
            east: r.x,
            depth: _depth(depths.isEmpty ? -r.z : _depthAt(depths, r.ms)),
          ),
      ]),
      originLatitude: originLatitude,
      originLongitude: originLongitude,
    );
  }

  /// The Depth channel linearly interpolated at [ms], holding the nearest
  /// reading outside the channel's span. The two share one sample clock, so
  /// no clock correction is needed between them.
  static double _depthAt(List<({int ms, double depth})> depths, int ms) {
    if (ms <= depths.first.ms) return depths.first.depth;
    if (ms >= depths.last.ms) return depths.last.depth;
    var lo = 0;
    var hi = depths.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) >> 1;
      if (depths[mid].ms <= ms) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final a = depths[lo];
    final b = depths[hi];
    if (b.ms == a.ms) return a.depth;
    return a.depth + (b.depth - a.depth) * (ms - a.ms) / (b.ms - a.ms);
  }

  /// Positive down; a small reading above the surface is clamped to zero.
  static double _depth(double value) => value < 0 ? 0.0 : value;

  static double? _finite(Object? value) {
    if (value is! num) return null;
    final d = value.toDouble();
    return d.isFinite ? d : null;
  }
}
