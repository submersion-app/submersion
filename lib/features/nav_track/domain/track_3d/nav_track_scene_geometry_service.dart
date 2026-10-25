import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_3d/domain/geometry/path_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';

/// Pure, synchronous assembly of the single-track path scene. Isolate-
/// friendly like its `dive_3d` counterpart (`SceneGeometryService`):
/// callers wrap it in `compute()`. X = run time, Y = depth, Z stays flat
/// at 0 everywhere -- a track has nothing worth putting on a third axis,
/// which is also `SceneGeometryService`'s own default whenever no Z
/// metric is picked (`Dive3dPage`'s own starting state).
///
/// Modeled on `SceneGeometryService.build`, with the dive-only pieces
/// dropped: no strata (temperature-binned tissue bands), no shadows or
/// ceiling (both deco-model concepts), no Z-axis metric, no markers (see
/// the design spec's Out of scope).
class NavTrackSceneGeometryService {
  static const int targetPoints = 2000;

  const NavTrackSceneGeometryService();

  Scene3d build(NavTrack3dSceneData data, TrackSceneMetric colorMetric) {
    final bounds = SceneBounds(
      durationSeconds: data.durationSeconds,
      maxDepthMeters: data.maxDepthMeters,
      sceneMinZ: -SceneBounds.zPathHalfSpan,
      sceneMaxZ: SceneBounds.zPathHalfSpan,
    );

    final indices = decimateSeriesIndices(
      data.depths,
      targetPoints: targetPoints,
    );
    List<double> pickD(List<double> s) => [for (final i in indices) s[i]];

    final times = pickD(data.times);
    final depths = pickD(data.depths);
    final colorValues = [
      for (final i in indices) data.seriesFor(colorMetric)[i],
    ];
    final sampleColors = TrackMetricPalette.colorsFor(colorValues);
    final zs = List<double>.filled(times.length, 0);

    final layers = [
      SceneLayer(
        RibbonBuilder.curtain(
          times: times,
          depths: depths,
          zs: zs,
          bounds: bounds,
        ),
      ),
      SceneLayer(
        PathBuilder.build(
          times: times,
          depths: depths,
          zs: zs,
          sampleColors: sampleColors,
          bounds: bounds,
        ),
      ),
    ];

    final duration = data.durationSeconds <= 0 ? 1.0 : data.durationSeconds;
    return Scene3d(
      layers: layers,
      markers: const [],
      bounds: bounds,
      scrubPath: ScrubPath(
        normalizedTimes: [for (final t in times) t / duration],
        xs: [for (final t in times) bounds.xOf(t)],
        ys: [for (final d in depths) bounds.yOf(d)],
        zs: zs,
      ),
    );
  }
}
