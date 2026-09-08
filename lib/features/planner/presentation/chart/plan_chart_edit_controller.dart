import 'dart:ui';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';

/// Pure gesture-to-mutation logic for on-chart waypoint editing.
///
/// Vertices are segment boundaries: vertex i sits at the END of user segment
/// i, which is its target depth. Moving one rewrites only that segment - the
/// next leg starts wherever this one now finishes, so there is nothing to
/// propagate and no type to re-derive.

class PlanVertex {
  final int segmentIndex;
  final String segmentId;
  final double timeSeconds;
  final double depth;
  final bool draggable;

  const PlanVertex({
    required this.segmentIndex,
    required this.segmentId,
    required this.timeSeconds,
    required this.depth,
    required this.draggable,
  });
}

class VertexDragResult {
  final List<(String, PlanSegment)> updates;

  const VertexDragResult(this.updates);
}

List<PlanVertex> planVertices(List<PlanSegment> segments) {
  final ordered = List<PlanSegment>.from(segments)
    ..sort((a, b) => a.order.compareTo(b.order));
  final vertices = <PlanVertex>[];
  var elapsed = 0.0;
  for (var i = 0; i < ordered.length; i++) {
    elapsed += ordered[i].durationSeconds;
    vertices.add(
      PlanVertex(
        segmentIndex: i,
        segmentId: ordered[i].id,
        timeSeconds: elapsed,
        depth: ordered[i].targetDepth,
        // Every waypoint is draggable. Gas-switch segments used to be
        // exempt; they no longer exist as a kind of segment.
        draggable: true,
      ),
    );
  }
  return vertices;
}

int? hitTestVertex({
  required List<PlanVertex> vertices,
  required PlanChartGeometry geometry,
  required Offset position,
  double radius = 16,
}) {
  int? best;
  var bestDistance = radius;
  for (var i = 0; i < vertices.length; i++) {
    if (!vertices[i].draggable) continue;
    final pixel = geometry.toPixel(vertices[i].timeSeconds, vertices[i].depth);
    final distance = (pixel - position).distance;
    if (distance <= bestDistance) {
      best = i;
      bestDistance = distance;
    }
  }
  return best;
}

double _snapDepth(double meters, double depthUnitScale) {
  final snapped = (meters * depthUnitScale).round() / depthUnitScale;
  return snapped.clamp(0.0, 330.0);
}

int _snapDuration(double seconds) {
  final minutes = (seconds / 60).round();
  return minutes < 1 ? 60 : minutes * 60;
}

VertexDragResult dragVertex({
  required List<PlanSegment> ordered,
  required int vertexIndex,
  required double newDepthMeters,
  required double newTimeSeconds,
  required double depthUnitScale,
}) {
  final depth = _snapDepth(newDepthMeters, depthUnitScale);
  var segmentStart = 0.0;
  for (var i = 0; i < vertexIndex; i++) {
    segmentStart += ordered[i].durationSeconds;
  }
  final duration = _snapDuration(newTimeSeconds - segmentStart);

  // Only the dragged segment changes. The old code also wrote the new depth
  // into the next segment's stored start depth, and rebuilt both through a
  // re-typing helper that dropped their per-segment setpoint and dive-mode
  // override on the way. copyWith preserves both.
  final segment = ordered[vertexIndex];
  return VertexDragResult([
    (
      segment.id,
      segment.copyWith(targetDepth: depth, durationSeconds: duration),
    ),
  ]);
}

({String replaceId, List<PlanSegment> replacements})? splitSegmentAt({
  required List<PlanSegment> ordered,
  required double timeSeconds,
  required double depthMeters,
  required double depthUnitScale,
  required String Function() idGen,
}) {
  if (ordered.isEmpty) return null;
  final depth = _snapDepth(depthMeters, depthUnitScale);

  var elapsed = 0.0;
  for (final segment in ordered) {
    final end = elapsed + segment.durationSeconds;
    if (timeSeconds <= end) {
      // Split this segment at a whole-minute boundary.
      final firstDuration = _snapDuration(timeSeconds - elapsed);
      final secondDuration = segment.durationSeconds - firstDuration;
      if (firstDuration < 60 || secondDuration < 60) return null;
      // The first half now turns at the split depth; the second keeps the
      // original target, so it picks up from wherever the first left off.
      final first = segment.copyWith(
        targetDepth: depth,
        durationSeconds: firstDuration,
      );
      final second = segment.copyWith(
        id: idGen(),
        durationSeconds: secondDuration,
      );
      return (replaceId: segment.id, replacements: [first, second]);
    }
    elapsed = end;
  }

  // Beyond the user span: append a waypoint at the tapped depth. It starts
  // wherever the last segment ends, so its phase follows from the two.
  final last = ordered.last;
  final duration = _snapDuration(timeSeconds - elapsed);
  final appended = PlanSegment(
    id: idGen(),
    targetDepth: depth,
    durationSeconds: duration,
    tankId: last.tankId,
    gasMix: last.gasMix,
    order: last.order + 1,
  );
  return (replaceId: '', replacements: [appended]);
}
