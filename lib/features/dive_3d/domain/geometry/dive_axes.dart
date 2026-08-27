import 'package:submersion/features/dive_3d/domain/geometry/axis_frame.dart';
import 'package:submersion/features/dive_3d/domain/geometry/nice_step.dart';
import 'package:submersion/features/dive_3d/domain/geometry/scene_bounds.dart';
import 'package:submersion/features/dive_3d/domain/geometry/z_axis_spec.dart';
import 'package:submersion/features/dive_3d/presentation/renderer/axis_labels.dart';

/// A tick on a dive axis: [value] in the axis's native unit (meters or
/// seconds), [text] already formatted for display.
class AxisTick {
  final double value;
  final String text;
  const AxisTick(this.value, this.text);
}

/// Depth ticks every [stepMeters] from the surface to the max depth, labeled
/// with the rounded display value ([toDisplay] converts meters to the
/// diver's unit). The unit symbol belongs in the axis title, not here.
List<AxisTick> depthAxisTicks({
  required double maxDepthMeters,
  required double stepMeters,
  required double Function(double meters) toDisplay,
}) {
  final ticks = <AxisTick>[const AxisTick(0, '0')];
  if (stepMeters <= 0) return ticks;
  for (var d = stepMeters; d <= maxDepthMeters + 1e-9; d += stepMeters) {
    ticks.add(AxisTick(d, toDisplay(d).round().toString()));
  }
  return ticks;
}

const List<int> _timeStepsSeconds = [60, 120, 300, 600, 900, 1800, 3600];

/// Whole-minute time ticks: the first step in the 1/2/5/10/15/30/60 min
/// ladder that yields at most six ticks across the runtime.
List<AxisTick> timeAxisTicks(double durationSeconds) {
  final step = _timeStepsSeconds.firstWhere(
    (s) => durationSeconds / s <= 6,
    orElse: () => 3600,
  );
  final ticks = <AxisTick>[const AxisTick(0, '0')];
  for (var t = step; t <= durationSeconds + 1e-9; t += step) {
    ticks.add(AxisTick(t.toDouble(), (t ~/ 60).toString()));
  }
  return ticks;
}

typedef DiveAxes = ({AxisFrame frame, AxisLabelSet labels});

/// Axes, ticks, labels, and wall grids for the path scene. Depth runs up the
/// front-left edge, time along the front floor edge, and the Z metric (when
/// present) along the right floor edge, so every axis sits on a visible
/// edge at the default pose. Pure geometry with pre-formatted strings:
/// titles arrive localized and unit-suffixed from the caller.
DiveAxes buildDiveAxes({
  required SceneBounds bounds,
  required List<AxisTick> depthTicks,
  required List<AxisTick> timeTicks,
  ZAxisSpec? zAxis,
  required String depthTitle,
  required String timeTitle,
  String? zTitle,
}) {
  const x0 = 0.0;
  const x1 = SceneBounds.xSpan;
  const yTop = 0.0;
  final yFloor = bounds.sceneMinY;
  final zBack = bounds.sceneMinZ;
  final zFront = bounds.sceneMaxZ;
  const tick = SceneBounds.xSpan * 0.02;

  final segments = <AxisSegment>[
    AxisSegment(AxisRole.axisY, x0, yTop, zFront, x0, yFloor, zFront),
    AxisSegment(AxisRole.axisX, x0, yFloor, zFront, x1, yFloor, zFront),
    // Box edges: back wall (4), floor (3 new), left wall (2 new).
    AxisSegment(AxisRole.frameGrid, x0, yTop, zBack, x1, yTop, zBack),
    AxisSegment(AxisRole.frameGrid, x0, yFloor, zBack, x1, yFloor, zBack),
    AxisSegment(AxisRole.frameGrid, x0, yTop, zBack, x0, yFloor, zBack),
    AxisSegment(AxisRole.frameGrid, x1, yTop, zBack, x1, yFloor, zBack),
    AxisSegment(AxisRole.frameGrid, x0, yFloor, zBack, x0, yFloor, zFront),
    AxisSegment(AxisRole.frameGrid, x1, yFloor, zBack, x1, yFloor, zFront),
    AxisSegment(AxisRole.frameGrid, x0, yFloor, zFront, x1, yFloor, zFront),
    AxisSegment(AxisRole.frameGrid, x0, yTop, zBack, x0, yTop, zFront),
    AxisSegment(AxisRole.frameGrid, x0, yTop, zFront, x0, yFloor, zFront),
  ];
  final labels = <AxisLabel>[
    AxisLabel(AxisLabelKind.title, x0, yTop, zFront, depthTitle),
    AxisLabel(AxisLabelKind.title, x1, yFloor, zFront, timeTitle),
  ];

  for (final t in depthTicks) {
    final y = bounds.yOf(t.value);
    segments.add(
      AxisSegment(AxisRole.tickY, x0, y, zFront, x0, y, zFront + tick),
    );
    segments.add(AxisSegment(AxisRole.frameGrid, x0, y, zBack, x1, y, zBack));
    segments.add(AxisSegment(AxisRole.frameGrid, x0, y, zBack, x0, y, zFront));
    labels.add(AxisLabel(AxisLabelKind.tick, x0, y, zFront, t.text));
  }
  for (final t in timeTicks) {
    final x = bounds.xOf(t.value);
    segments.add(
      AxisSegment(AxisRole.tickX, x, yFloor, zFront, x, yFloor, zFront + tick),
    );
    segments.add(
      AxisSegment(AxisRole.frameGrid, x, yTop, zBack, x, yFloor, zBack),
    );
    segments.add(
      AxisSegment(AxisRole.frameGrid, x, yFloor, zBack, x, yFloor, zFront),
    );
    labels.add(AxisLabel(AxisLabelKind.tick, x, yFloor, zFront, t.text));
  }
  if (zAxis != null) {
    segments.add(
      AxisSegment(AxisRole.axisZ, x1, yFloor, zFront, x1, yFloor, zBack),
    );
    labels.add(
      AxisLabel(AxisLabelKind.title, x1, yFloor, zBack, zTitle ?? zAxis.symbol),
    );
    for (final v in zAxis.ticks) {
      final z = zAxis.zOf(v);
      segments.add(
        AxisSegment(AxisRole.tickZ, x1, yFloor, z, x1 + tick, yFloor, z),
      );
      segments.add(
        AxisSegment(AxisRole.frameGrid, x0, yFloor, z, x1, yFloor, z),
      );
      segments.add(AxisSegment(AxisRole.frameGrid, x0, yTop, z, x0, yFloor, z));
      labels.add(
        AxisLabel(
          AxisLabelKind.tick,
          x1,
          yFloor,
          z,
          formatTickValue(v, zAxis.step),
        ),
      );
    }
  }
  return (frame: AxisFrame(segments), labels: AxisLabelSet(labels));
}
