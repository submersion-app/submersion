import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ceiling_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/grid_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strata_builder.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_3d.dart';
import 'package:submersion/features/dive_3d/presentation/scene_overlay.dart';

/// Pure, synchronous assembly of the single-dive scene. Isolate-friendly:
/// callers wrap it in compute() (repo convention: the pure worker is the
/// tested unit, the isolate hop is not). Produces the renderer-neutral
/// [Scene3d] every dive_3d scene shares.
class SceneGeometryService {
  static const int targetPoints = 2000;

  const SceneGeometryService();

  Scene3d build(
    Dive3dSceneData data,
    SceneMetric metric, {
    double gridStepMeters = 10.0,
  }) {
    final bounds = SceneBounds(
      durationSeconds: data.durationSeconds,
      maxDepthMeters: data.maxDepthMeters,
    );

    final indices = decimateSeriesIndices(
      data.depths,
      targetPoints: targetPoints,
    );
    List<double> pickD(List<double> s) => [for (final i in indices) s[i]];
    List<double?> pickN(List<double?> s) => [for (final i in indices) s[i]];

    final times = pickD(data.times);
    final depths = pickD(data.depths);
    final metricValues = _metricSeries(data, metric, indices);
    final sampleColors = MetricPalette.colorsFor(metric, metricValues);

    final strata = StrataBuilder.build(
      bands: StrataBuilder.bin(
        depths: data.depths,
        temperatures: data.temperatures,
      ),
      bounds: bounds,
    );
    final ceiling = CeilingBuilder.build(
      times: times,
      depths: depths,
      ceilings: pickN(data.ceilings),
      bounds: bounds,
    );
    final grid = GridBuilder.build(bounds: bounds, stepMeters: gridStepMeters);

    final layers = <SceneLayer>[
      if (grid != null) SceneLayer(grid),
      if (strata != null) SceneLayer(strata, overlay: SceneOverlay.strata),
      SceneLayer(
        RibbonBuilder.curtain(times: times, depths: depths, bounds: bounds),
        overlay: SceneOverlay.curtain,
      ),
      if (ceiling != null) SceneLayer(ceiling, overlay: SceneOverlay.ceiling),
      SceneLayer(
        RibbonBuilder.build(
          times: times,
          depths: depths,
          sampleColors: sampleColors,
          bounds: bounds,
        ),
      ),
    ];

    final duration = data.durationSeconds <= 0 ? 1.0 : data.durationSeconds;
    return Scene3d(
      layers: layers,
      markers: MarkerLayout.layout(data: data, bounds: bounds),
      bounds: bounds,
      scrubPath: ScrubPath(
        normalizedTimes: [for (final t in times) t / duration],
        xs: [for (final t in times) bounds.xOf(t)],
        ys: [for (final d in depths) bounds.yOf(d)],
      ),
    );
  }

  List<double?> _metricSeries(
    Dive3dSceneData data,
    SceneMetric metric,
    List<int> indices,
  ) {
    List<double?> pick(List<double?> s) => [for (final i in indices) s[i]];
    switch (metric) {
      case SceneMetric.depth:
        return pick(data.depths.cast<double?>());
      case SceneMetric.temperature:
        return pick(data.temperatures);
      case SceneMetric.ascentRate:
        return pick(data.ascentRates);
      case SceneMetric.ppO2:
        return pick(data.ppO2s);
      case SceneMetric.cns:
        return pick(data.cnss);
      case SceneMetric.heartRate:
        return pick(data.heartRates);
      case SceneMetric.tankPressure:
        return _resampledPressure(data, indices);
    }
  }

  /// Tank-pressure coloring uses the first tank's series resampled onto
  /// the (decimated) profile timestamps.
  List<double?> _resampledPressure(Dive3dSceneData data, List<int> indices) {
    final series = data.tankPressures.values
        .where((points) => points.isNotEmpty)
        .toList();
    if (series.isEmpty) {
      return List<double?>.filled(indices.length, null);
    }
    final points = series.first;
    final lookup = ProfileLookupOverPressure(points);
    return [for (final i in indices) lookup.at(data.times[i])];
  }
}

/// Small interpolating lookup over a tank-pressure time series.
class ProfileLookupOverPressure {
  final List<double> times;
  final List<double> values;

  ProfileLookupOverPressure(List<TankPressurePoint> points)
    : times = [for (final p in points) p.timestamp.toDouble()],
      values = [for (final p in points) p.pressure];

  double? at(double t) {
    if (times.isEmpty) return null;
    if (t <= times.first) return values.first;
    if (t >= times.last) return values.last;
    var lo = 0, hi = times.length - 1;
    while (hi - lo > 1) {
      final mid = (lo + hi) ~/ 2;
      if (times[mid] <= t) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    final span = times[hi] - times[lo];
    if (span <= 0) return values[lo];
    return values[lo] + (values[hi] - values[lo]) * ((t - times[lo]) / span);
  }
}
