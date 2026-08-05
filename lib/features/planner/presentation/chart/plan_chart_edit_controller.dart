import 'dart:ui';

import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';

/// Pure gesture-to-mutation logic for on-chart waypoint editing.
///
/// Vertices are segment boundaries: vertex i sits at the END of user segment
/// i. Moving one uses waypoint semantics - the segment ending there and the
/// segment starting there both follow, and their types are re-derived from
/// the resulting slopes (Subsurface's model mapped onto our segment list).

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
        depth: ordered[i].endDepth,
        draggable: ordered[i].type != SegmentType.gasSwitch,
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

/// Re-derive a segment's type from its slope after an edit. Flat segments
/// keep their flat identity; sloped ones become descent/ascent with the
/// stored rate cleared (it no longer matches).
PlanSegment _retyped(PlanSegment segment) {
  if (segment.type == SegmentType.gasSwitch) return segment;
  if (segment.startDepth == segment.endDepth) {
    final flat = switch (segment.type) {
      SegmentType.bottom ||
      SegmentType.decoStop ||
      SegmentType.safetyStop => segment.type,
      _ => SegmentType.bottom,
    };
    return segment.copyWith(type: flat);
  }
  return PlanSegment(
    id: segment.id,
    type: segment.startDepth < segment.endDepth
        ? SegmentType.descent
        : SegmentType.ascent,
    startDepth: segment.startDepth,
    endDepth: segment.endDepth,
    durationSeconds: segment.durationSeconds,
    tankId: segment.tankId,
    gasMix: segment.gasMix,
    switchToTankId: segment.switchToTankId,
    order: segment.order,
  );
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

  final updates = <(String, PlanSegment)>[];
  final segment = ordered[vertexIndex];
  updates.add((
    segment.id,
    _retyped(segment.copyWith(endDepth: depth, durationSeconds: duration)),
  ));
  if (vertexIndex + 1 < ordered.length) {
    final next = ordered[vertexIndex + 1];
    updates.add((next.id, _retyped(next.copyWith(startDepth: depth))));
  }
  return VertexDragResult(updates);
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
      final first = _retyped(
        segment.copyWith(endDepth: depth, durationSeconds: firstDuration),
      );
      final second = _retyped(
        segment.copyWith(
          id: idGen(),
          startDepth: depth,
          durationSeconds: secondDuration,
        ),
      );
      return (replaceId: segment.id, replacements: [first, second]);
    }
    elapsed = end;
  }

  // Beyond the user span: append a travel segment from the last depth.
  final last = ordered.last;
  final duration = _snapDuration(timeSeconds - elapsed);
  final appended = _retyped(
    PlanSegment(
      id: idGen(),
      type: SegmentType.bottom,
      startDepth: last.endDepth,
      endDepth: depth,
      durationSeconds: duration,
      tankId: last.tankId,
      gasMix: last.gasMix,
      order: last.order + 1,
    ),
  );
  return (replaceId: '', replacements: [appended]);
}
