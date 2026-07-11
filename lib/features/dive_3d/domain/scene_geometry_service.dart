import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/widgets/profile_decimator.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/entities/mesh_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ceiling_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/marker_layout.dart';
import 'package:submersion/features/dive_3d/domain/geometry/ribbon_builder.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/strata_builder.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';

/// The complete renderable output for one dive + metric. Renderer-neutral.
class Dive3dGeometry {
  final MeshData ribbon;
  final MeshData curtain;
  final MeshData? strata;
  final MeshData? ceilingSurface;
  final List<SceneMarker> markers;
  final SceneBounds bounds;

  const Dive3dGeometry({
    required this.ribbon,
    required this.curtain,
    required this.strata,
    required this.ceilingSurface,
    required this.markers,
    required this.bounds,
  });
}

/// Pure, synchronous geometry assembly. Isolate-friendly: callers wrap it
/// in compute() (repo convention: the pure worker is the tested unit, the
/// isolate hop is not).
class SceneGeometryService {
  static const int targetPoints = 2000;

  const SceneGeometryService();

  Dive3dGeometry build(Dive3dSceneData data, SceneMetric metric) {
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

    return Dive3dGeometry(
      ribbon: RibbonBuilder.build(
        times: times,
        depths: depths,
        sampleColors: sampleColors,
        bounds: bounds,
      ),
      curtain: RibbonBuilder.curtain(
        times: times,
        depths: depths,
        bounds: bounds,
      ),
      strata: StrataBuilder.build(
        bands: StrataBuilder.bin(
          depths: data.depths,
          temperatures: data.temperatures,
        ),
        bounds: bounds,
      ),
      ceilingSurface: CeilingBuilder.build(
        times: times,
        depths: depths,
        ceilings: pickN(data.ceilings),
        bounds: bounds,
      ),
      markers: MarkerLayout.layout(data: data, bounds: bounds),
      bounds: bounds,
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
