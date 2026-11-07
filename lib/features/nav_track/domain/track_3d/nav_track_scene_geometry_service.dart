import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/path_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_series.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_z_axis_input.dart';

/// Pure, synchronous assembly of the single-track path scene. Isolate-
/// friendly like its `dive_3d` counterpart (`SceneGeometryService`):
/// callers wrap it in `compute()`. X = run time, Y = depth, Z = the metric
/// in [zAxis] (flat at 0 when null or when the series has too few samples
/// to form a path -- `SceneGeometryService`'s own default too).
///
/// Modeled on `SceneGeometryService.build`, with the dive-only pieces
/// dropped: no strata (temperature-binned tissue bands), no shadows or
/// ceiling (both deco-model concepts). Its only markers are the ones the
/// recording console set (issue #4231), labelled with the number the 2D
/// map gives them.
class NavTrackSceneGeometryService {
  static const int targetPoints = 2000;

  const NavTrackSceneGeometryService();

  /// Lifts a marker label this far above the path, like the dive scene's
  /// own markers (`MarkerLayout`).
  static const double _markerFloat = 0.4;

  /// [data]'s console markers, placed on the path at their own sample. Z is
  /// read from the decimated path's nearest sample, so a marker sits on the
  /// drawn line rather than beside it.
  static List<SceneMarker> _markers(
    NavTrack3dSceneData data,
    SceneBounds bounds,
    List<int> indices,
    List<double> zs,
  ) {
    if (data.markers.isEmpty || indices.isEmpty) return const [];
    double zAt(int sampleIndex) {
      var best = 0;
      for (var i = 1; i < indices.length; i++) {
        if ((indices[i] - sampleIndex).abs() <
            (indices[best] - sampleIndex).abs()) {
          best = i;
        }
      }
      return zs[best];
    }

    return [
      for (final marker in data.markers)
        if (marker.sampleIndex < data.times.length)
          SceneMarker(
            kind: SceneMarkerKind.bookmark,
            refId: null,
            label: '${marker.number}',
            x: bounds.xOf(data.times[marker.sampleIndex]),
            y: bounds.yOf(data.depths[marker.sampleIndex]) + _markerFloat,
            z: zAt(marker.sampleIndex),
            timestampSeconds: data.times[marker.sampleIndex].round(),
          ),
    ];
  }

  Scene3d build(
    NavTrack3dSceneData data,
    TrackSceneMetric colorMetric, {
    TrackZAxisInput? zAxis,
  }) {
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
    final colorSeries = data.seriesFor(colorMetric);
    final sampleColors = MetricPalette.rampColorsFor([
      for (final i in indices) colorSeries[i],
    ]);

    final zValues = zAxis == null
        ? null
        : resampleZSeries(values: zAxis.values, indices: indices);
    final hasZ = zAxis != null && zValues != null;
    final zs = hasZ
        ? [for (final v in zValues) zAxis.spec.zOf(v)]
        : List<double>.filled(times.length, 0);

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
      markers: _markers(data, bounds, indices, zs),
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
