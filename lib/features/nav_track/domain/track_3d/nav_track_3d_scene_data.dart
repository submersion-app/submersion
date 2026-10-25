import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/nav_track_corrector.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';

/// Everything the track 3D scene needs, extracted from [NavTrack] into
/// parallel plain-Dart series. Pure data, mirroring `dive_3d`'s
/// `Dive3dSceneData`: no Drift, no Riverpod, no engine imports, so it
/// crosses isolates and is trivially testable.
///
/// Scoped to [NavTrackCorrector.activeRange] -- the same boundary
/// `NavTrackStats.of` and the 2D polyline layer already stop at: a
/// post-dive GPS fix sample and the out-of-water walk after it are
/// calibration, not the dive. A recording with no fix event at all (a
/// cave dive, no surface contact) falls back to the whole recording,
/// the same way `NavTrackStats.of` already does for that case.
class NavTrack3dSceneData {
  final List<double> times;
  final List<double> depths;
  final List<double?> temperatures;
  final List<double?> speeds;
  final List<double?> batteryVolts;
  final double durationSeconds;
  final double maxDepthMeters;

  const NavTrack3dSceneData({
    required this.times,
    required this.depths,
    required this.temperatures,
    required this.speeds,
    required this.batteryVolts,
    required this.durationSeconds,
    required this.maxDepthMeters,
  });

  factory NavTrack3dSceneData.fromRoute(NavTrack route) {
    if (route.points.isEmpty) {
      return const NavTrack3dSceneData(
        times: [],
        depths: [],
        temperatures: [],
        speeds: [],
        batteryVolts: [],
        durationSeconds: 0,
        maxDepthMeters: 0,
      );
    }
    final range = NavTrackCorrector.activeRange(route.points);
    // Never empty: activeRange's end is at least its start on a non-empty
    // recording.
    final active = route.points.sublist(range.start, range.end + 1);
    final startTimestamp = active.first.timestamp;

    var maxDepth = 0.0;
    for (final p in active) {
      if (p.depth > maxDepth) maxDepth = p.depth;
    }

    return NavTrack3dSceneData(
      times: [
        for (final p in active) (p.timestamp - startTimestamp).toDouble(),
      ],
      depths: [for (final p in active) p.depth],
      temperatures: [for (final p in active) p.temperature],
      speeds: [for (final p in active) p.speed],
      // Every sample, not just the first and last the detail page's summary
      // reads, so the color ramp, Z axis and readout agree with it.
      batteryVolts: [for (final p in active) p.plausibleBatteryVolts],
      durationSeconds: (active.last.timestamp - startTimestamp).toDouble(),
      maxDepthMeters: maxDepth,
    );
  }

  bool get hasProfile => times.length >= 2;

  bool _any(List<double?> series) => series.any((v) => v != null && v.isFinite);

  /// Metrics with at least one real sample. Depth is always available --
  /// a point with no depth reading does not exist in this entity (`depth`
  /// is non-nullable on [NavTrackPoint]).
  Set<TrackSceneMetric> get availableMetrics => {
    TrackSceneMetric.depth,
    if (_any(temperatures)) TrackSceneMetric.temperature,
    if (_any(speeds)) TrackSceneMetric.speed,
    if (_any(batteryVolts)) TrackSceneMetric.batteryVoltage,
  };

  int _finiteCount(List<double?> series) =>
      series.where((v) => v != null && v.isFinite).length;

  /// Metrics that can drive the Z axis: at least two finite samples so a
  /// path exists between them. Unlike `Dive3dSceneData.zAxisMetrics`,
  /// depth is offered too -- the diver asked for every metric to be
  /// selectable on Z, Y's own depth-as-the-vertical-axis role included.
  Set<TrackSceneMetric> get zAxisMetrics => {
    if (depths.length >= 2) TrackSceneMetric.depth,
    if (_finiteCount(temperatures) >= 2) TrackSceneMetric.temperature,
    if (_finiteCount(speeds) >= 2) TrackSceneMetric.speed,
    if (_finiteCount(batteryVolts) >= 2) TrackSceneMetric.batteryVoltage,
  };

  List<double?> seriesFor(TrackSceneMetric metric) => switch (metric) {
    TrackSceneMetric.depth => depths.cast<double?>(),
    TrackSceneMetric.temperature => temperatures,
    TrackSceneMetric.speed => speeds,
    TrackSceneMetric.batteryVoltage => batteryVolts,
  };
}
