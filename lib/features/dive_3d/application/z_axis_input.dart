import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/entities/dive_3d_scene_data.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/domain/metric_palette.dart';
import 'package:submersion/features/dive_3d/domain/scene_geometry_service.dart';

/// Converts [metric]'s full-resolution series into the diver's display
/// units and fits a nice axis around it. Returns null when fewer than two
/// finite samples exist (no path to draw), which the UI shows as None.
ZAxisInput? buildZAxisInput(
  Dive3dSceneData data,
  SceneMetric metric,
  UnitFormatter units,
) {
  final (values, symbol) = switch (metric) {
    SceneMetric.depth => throw ArgumentError('depth is the Y axis'),
    SceneMetric.temperature => (
      [
        for (final t in data.temperatures)
          t == null ? null : units.convertTemperature(t),
      ],
      units.temperatureSymbol,
    ),
    SceneMetric.ascentRate => (
      [
        for (final r in data.ascentRates)
          r == null ? null : units.convertDepth(r),
      ],
      '${units.depthSymbol}/min',
    ),
    SceneMetric.ppO2 => (data.ppO2s, ''),
    SceneMetric.cns => (data.cnss, '%'),
    SceneMetric.heartRate => (data.heartRates, 'bpm'),
    SceneMetric.tts => (
      [for (final s in data.ttsSeconds) s == null ? null : s / 60],
      'min',
    ),
    SceneMetric.tankPressure => (
      _tankSeries(data, units),
      units.pressureSymbol,
    ),
  };
  final finite = [
    for (final v in values)
      if (v != null && v.isFinite) v,
  ];
  if (finite.length < 2) return null;
  var min = finite.first, max = finite.first;
  for (final v in finite) {
    if (v < min) min = v;
    if (v > max) max = v;
  }
  return ZAxisInput(
    metric: metric,
    spec: ZAxisSpec.fromRange(min: min, max: max, symbol: symbol),
    values: values,
  );
}

List<double?> _tankSeries(Dive3dSceneData data, UnitFormatter units) {
  final series = data.tankPressures.values.where((p) => p.isNotEmpty).toList();
  if (series.isEmpty) return List<double?>.filled(data.times.length, null);
  final lookup = ProfileLookupOverPressure(series.first);
  return [
    for (final t in data.times)
      switch (lookup.at(t)) {
        null => null,
        final bar => units.convertPressure(bar),
      },
  ];
}
