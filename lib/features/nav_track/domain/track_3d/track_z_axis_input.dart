import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/nav_track/domain/track_3d/nav_track_3d_scene_data.dart';
import 'package:submersion/features/nav_track/domain/track_3d/track_scene_metric.dart';

/// Everything the track geometry service needs to put a metric on Z: its
/// axis and the full-resolution series in display units. No `metric` field
/// (unlike `dive_3d`'s `ZAxisInput`) -- the page already tracks the chosen
/// [TrackSceneMetric] in its own state, so nothing downstream needs it
/// echoed back.
class TrackZAxisInput {
  final ZAxisSpec spec;
  final List<double?> values;

  const TrackZAxisInput({required this.spec, required this.values});
}

/// Converts [metric]'s full-resolution series into the diver's display
/// units and fits a nice axis around it, mirroring `dive_3d`'s
/// `buildZAxisInput`. Returns null when fewer than two finite samples
/// exist (no path to draw), which the UI shows as None.
TrackZAxisInput? buildTrackZAxisInput(
  NavTrack3dSceneData data,
  TrackSceneMetric metric,
  UnitFormatter units,
) {
  final (values, symbol) = switch (metric) {
    TrackSceneMetric.depth => (
      <double?>[for (final d in data.depths) units.convertDepth(d)],
      units.depthSymbol,
    ),
    TrackSceneMetric.temperature => (
      [
        for (final t in data.temperatures)
          t == null ? null : units.convertTemperature(t),
      ],
      units.temperatureSymbol,
    ),
    TrackSceneMetric.speed => (
      [
        for (final s in data.speeds)
          s == null ? null : units.convertTrackSpeed(s),
      ],
      units.trackSpeedSymbol,
    ),
    TrackSceneMetric.batteryVoltage => (data.batteryVolts, 'V'),
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
  return TrackZAxisInput(
    spec: ZAxisSpec.fromRange(min: min, max: max, symbol: symbol),
    values: values,
  );
}
