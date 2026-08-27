import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/tissue/tissue_surface_grid.dart';

/// A title (names an axis) or a tick (a value along an axis).
enum AxisLabelKind { title, tick }

/// A text label anchored to a world (scene) coordinate. The painter projects
/// the anchor and draws [text] near it, so labels track the rotating camera.
class AxisLabel {
  final AxisLabelKind kind;
  final double x, y, z;
  final String text;
  const AxisLabel(this.kind, this.x, this.y, this.z, this.text);
}

class AxisLabelSet {
  final List<AxisLabel> labels;
  const AxisLabelSet(this.labels);
}

/// Builds axis titles + tick-value labels for the tissue scene. Titles are
/// resolved (localized) by the caller; tick values are plain numbers. Time
/// ticks read in whole minutes derived from [runtimeSeconds] and are omitted
/// when the runtime is unknown (the surface X axis is normalized progress, so
/// without a runtime there is no meaningful minute value).
AxisLabelSet buildTissueAxisLabels({
  required SceneBounds bounds,
  required TissueSurfaceGrid grid,
  required double referenceY,
  required String timeTitle,
  required String saturationTitle,
  required String compartmentTitle,
  int? runtimeSeconds,
}) {
  const x0 = 0.0;
  const x1 = SceneBounds.xSpan;
  final y0 = bounds.sceneMinY;
  final y1 = bounds.sceneMaxY;
  final z0 = bounds.sceneMinZ;
  final z1 = bounds.sceneMaxZ;

  final labels = <AxisLabel>[
    AxisLabel(AxisLabelKind.title, x1, y0, z0, timeTitle),
    AxisLabel(AxisLabelKind.title, x0, y1, z0, saturationTitle),
    AxisLabel(AxisLabelKind.title, x0, y0, z1, compartmentTitle),
  ];

  // Saturation axis: 0 / 50 / 100 (%). 100 sits on the M-value plane. The axis
  // runs from the floor (y0) up to referenceY, so interpolate from y0 -- the
  // same geometry AxisFrame uses for the tick marks -- rather than from world
  // 0, which would drift the labels off the ticks when y0 != 0.
  for (final pct in const [0, 50, 100]) {
    final y = y0 + (referenceY - y0) * (pct / 100.0);
    labels.add(AxisLabel(AxisLabelKind.tick, x0, y, z0, '$pct'));
  }

  // Compartment axis: fast / middle / slow compartment numbers.
  if (!grid.isEmpty) {
    final idxs = <int>{0, (grid.compartments - 1) ~/ 2, grid.compartments - 1};
    for (final idx in idxs) {
      final z = grid.positionAt(0, idx).$3;
      labels.add(
        AxisLabel(
          AxisLabelKind.tick,
          x0,
          y0,
          z,
          '${grid.compartmentNumbers[idx]}',
        ),
      );
    }
  }

  // Time axis: whole minutes at 25 / 50 / 75 / 100% of the run.
  if (runtimeSeconds != null && runtimeSeconds > 0) {
    for (final frac in const [0.25, 0.5, 0.75, 1.0]) {
      final x = frac * x1;
      final minutes = (frac * runtimeSeconds / 60).round();
      labels.add(AxisLabel(AxisLabelKind.tick, x, y0, z0, '$minutes'));
    }
  }

  return AxisLabelSet(labels);
}
