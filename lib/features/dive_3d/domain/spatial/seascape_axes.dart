import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/spatial/spatial_projection.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';

/// The scene-frame numbers the axes are built from, captured where the
/// scene's projection is built (plain record: crosses compute() cheaply).
typedef SeascapeAxisInputs = ({
  double minEast,
  double maxEast,
  double minNorth,
  double maxNorth,
  double maxDepth,
});

/// The seascape's measurement chrome: a map-frame at the waterline (two
/// distance axes along the south and west edges) plus a depth axis
/// descending at the origin corner. No reference grids — axes, ticks, and
/// labels only, so the scenic view stays clean.
class SeascapeAxes {
  final AxisFrame frame;
  final AxisLabelSet labels;

  const SeascapeAxes({required this.frame, required this.labels});
}

/// Builds the axes for a seascape scene. Tick values are nice steps in the
/// diver's display unit ([displayUnitInMeters]: 1.0 for meters, 0.3048 for
/// feet), measured from the origin corner; the 0 label is skipped on every
/// axis. Titles arrive fully composed (localized, unit symbol included).
/// Pure geometry: safe under compute() and trivially testable.
SeascapeAxes buildSeascapeAxes({
  required SpatialProjection projection,
  required double minEast,
  required double maxEast,
  required double minNorth,
  required double maxNorth,
  required double maxDepthMeters,
  required double displayUnitInMeters,
  required String distanceTitle,
  required String depthTitle,
}) {
  const tickLen = SceneBounds.xSpan * 0.02;
  final p = projection;
  final x0 = p.xOf(minEast);
  final x1 = p.xOf(maxEast);
  final z0 = p.zOf(minNorth);
  final z1 = p.zOf(maxNorth);
  final yBottom = p.yOf(maxDepthMeters);
  // Ticks poke OUTWARD, away from the terrain. The map frame runs Z south
  // (see SpatialProjection), so z0 is the LARGER scene Z; deriving each
  // sign from the axis itself keeps the ticks outside the grid whichever
  // way the frame points.
  final xTick = x0 + (x0 - x1).sign * tickLen;
  final zTick = z0 + (z0 - z1).sign * tickLen;

  final segments = <AxisSegment>[
    AxisSegment(AxisRole.axisX, x0, 0, z0, x1, 0, z0),
    AxisSegment(AxisRole.axisZ, x0, 0, z0, x0, 0, z1),
    AxisSegment(AxisRole.axisY, x0, 0, z0, x0, yBottom, z0),
  ];
  final labels = <AxisLabel>[
    AxisLabel(AxisLabelKind.title, x1, 0, z0, distanceTitle),
    AxisLabel(AxisLabelKind.title, x0, yBottom, z0, depthTitle),
  ];

  // Distance ticks (X and Z share span-derived steps; the projection's
  // uniform horizontal scale keeps one step honest for both).
  void distanceTicks({
    required double spanMeters,
    required int divisions,
    required void Function(double meters, String text) emit,
  }) {
    final spanDisplay = spanMeters / displayUnitInMeters;
    final step = niceStep(spanDisplay / divisions);
    if (step <= 0) return;
    for (var v = step; v <= spanDisplay + 1e-9; v += step) {
      emit(v * displayUnitInMeters, formatTickValue(v, step));
    }
  }

  distanceTicks(
    spanMeters: maxEast - minEast,
    divisions: 5,
    emit: (meters, text) {
      final x = p.xOf(minEast + meters);
      segments.add(AxisSegment(AxisRole.tickX, x, 0, z0, x, 0, zTick));
      labels.add(AxisLabel(AxisLabelKind.tick, x, 0, z0, text));
    },
  );
  distanceTicks(
    spanMeters: maxNorth - minNorth,
    divisions: 5,
    emit: (meters, text) {
      final z = p.zOf(minNorth + meters);
      segments.add(AxisSegment(AxisRole.tickZ, x0, 0, z, xTick, 0, z));
      labels.add(AxisLabel(AxisLabelKind.tick, x0, 0, z, text));
    },
  );
  distanceTicks(
    spanMeters: maxDepthMeters,
    divisions: 4,
    emit: (meters, text) {
      final y = p.yOf(meters);
      segments.add(AxisSegment(AxisRole.tickY, x0, y, z0, xTick, y, z0));
      labels.add(AxisLabel(AxisLabelKind.tick, x0, y, z0, text));
    },
  );

  return SeascapeAxes(frame: AxisFrame(segments), labels: AxisLabelSet(labels));
}
