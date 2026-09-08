import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    show PlanMode;
import 'package:submersion/features/planner/domain/entities/segment_phase.dart';
import 'package:submersion/features/planner/domain/services/segment_chain.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';

const _gas = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);
const _chain = SegmentChain();

PlanSegment _descent({String id = 'd', double to = 30, int seconds = 120}) =>
    PlanSegment(
      id: id,
      targetDepth: to,
      durationSeconds: seconds,
      tankId: 't1',
      gasMix: _gas,
      order: 0,
    );

PlanSegment _bottom({
  String id = 'b',
  double depth = 30,
  int seconds = 1200,
  int order = 1,
}) => PlanSegment(
  id: id,
  targetDepth: depth,
  durationSeconds: seconds,
  tankId: 't1',
  gasMix: _gas,
  order: order,
);

/// What a gas switch is now: a leg on a different tank. There is no
/// gas-switch kind of segment to exempt from dragging.
PlanSegment _decoGasLeg({String id = 'g', double depth = 21, int order = 2}) =>
    PlanSegment(
      id: id,
      targetDepth: depth,
      durationSeconds: 60,
      tankId: 't2',
      gasMix: _ean50,
      order: order,
    );

/// Phase of the segment with [id] once the whole list is chained.
SegmentPhase _phaseOf(List<PlanSegment> segments, String id) =>
    _chain.resolve(segments).firstWhere((leg) => leg.segment.id == id).phase;

double _startOf(List<PlanSegment> segments, String id) => _chain
    .resolve(segments)
    .firstWhere((leg) => leg.segment.id == id)
    .startDepth;

void main() {
  group('planVertices', () {
    test('one vertex per segment with cumulative end times', () {
      final vertices = planVertices([_descent(), _bottom()]);
      expect(vertices, hasLength(2));
      expect(vertices[0].timeSeconds, 120);
      expect(vertices[0].depth, 30);
      expect(vertices[1].timeSeconds, 1320);
      expect(vertices[1].segmentId, 'b');
    });

    test('every vertex is draggable, including a deco-gas leg', () {
      final vertices = planVertices([_descent(), _bottom(), _decoGasLeg()]);
      expect(vertices[2].timeSeconds, 1380);
      expect(vertices.every((v) => v.draggable), isTrue);
    });
  });

  group('hitTestVertex', () {
    const geometry = PlanChartGeometry(
      size: Size(500, 400),
      maxTimeSeconds: 1320,
      maxDepthMeters: 30,
      depthUnitScale: 1,
    );

    test('finds the nearest draggable vertex within radius', () {
      final vertices = planVertices([_descent(), _bottom()]);
      final target = geometry.toPixel(120, 30);
      expect(
        hitTestVertex(
          vertices: vertices,
          geometry: geometry,
          position: target.translate(5, -5),
        ),
        0,
      );
    });

    test('misses outside the radius', () {
      final vertices = planVertices([_descent(), _bottom()]);
      expect(
        hitTestVertex(
          vertices: vertices,
          geometry: geometry,
          position: const Offset(5, 5),
        ),
        isNull,
      );
    });
  });

  group('dragVertex', () {
    test('rewrites only the dragged segment; the next leg follows', () {
      final ordered = [_descent(), _bottom(), _bottom(id: 'b2', order: 2)];
      final result = dragVertex(
        ordered: ordered,
        vertexIndex: 1,
        newDepthMeters: 35.4,
        newTimeSeconds: 1320,
        depthUnitScale: 1,
      );

      // One update, not two: the old controller also wrote the new depth into
      // the next segment's stored start depth.
      expect(result.updates, hasLength(1));
      final b = result.updates.single;
      expect(b.$1, 'b');
      expect(b.$2.targetDepth, 35); // snapped to whole meters

      // b2 still targets 30 m, so chaining makes it an ascent from 35 m -
      // no stored start depth had to be patched to get there.
      final after = [ordered[0], b.$2, ordered[2]];
      expect(_phaseOf(after, 'b'), SegmentPhase.descent);
      expect(_startOf(after, 'b2'), 35);
      expect(_phaseOf(after, 'b2'), SegmentPhase.ascent);
    });

    test('preserves the CCR setpoint and dive-mode override', () {
      // Regression: the old re-typing helper rebuilt sloped segments through
      // a raw constructor and silently dropped both.
      final bottom = _bottom().copyWith(
        setpointBar: 1.3,
        diveModeOverride: PlanMode.oc,
      );
      final result = dragVertex(
        ordered: [_descent(), bottom],
        vertexIndex: 1,
        newDepthMeters: 35,
        newTimeSeconds: 1320,
        depthUnitScale: 1,
      );

      final updated = result.updates.single.$2;
      expect(updated.setpointBar, 1.3);
      expect(updated.diveModeOverride, PlanMode.oc);
    });

    test('duration snaps to whole minutes with a 60s floor', () {
      final ordered = [_descent(), _bottom()];
      final result = dragVertex(
        ordered: ordered,
        vertexIndex: 1,
        newDepthMeters: 30,
        newTimeSeconds: 120 + 754, // 12.6 min after segment start
        depthUnitScale: 1,
      );
      final b = result.updates.singleWhere((u) => u.$1 == 'b').$2;
      expect(b.durationSeconds, 780); // 13 whole minutes
      expect(_phaseOf([ordered[0], b], 'b'), SegmentPhase.level);

      final tiny = dragVertex(
        ordered: ordered,
        vertexIndex: 1,
        newDepthMeters: 30,
        newTimeSeconds: 130,
        depthUnitScale: 1,
      );
      expect(
        tiny.updates.singleWhere((u) => u.$1 == 'b').$2.durationSeconds,
        60,
      );
    });

    test('depth snaps in display units (feet)', () {
      final ordered = [_descent(), _bottom()];
      final result = dragVertex(
        ordered: ordered,
        vertexIndex: 0,
        newDepthMeters: 30.2,
        newTimeSeconds: 120,
        depthUnitScale: 3.2808,
      );
      final d = result.updates.singleWhere((u) => u.$1 == 'd').$2;
      // 30.2 m = 99.08 ft -> 99 ft -> 30.175... m
      expect(d.targetDepth, closeTo(99 / 3.2808, 0.001));
    });
  });

  group('splitSegmentAt', () {
    test('splits the covering segment keeping the original id first', () {
      final ordered = [_descent(), _bottom()];
      final split = splitSegmentAt(
        ordered: ordered,
        timeSeconds: 120 + 400, // inside the bottom segment
        depthMeters: 24.6,
        depthUnitScale: 1,
        idGen: () => 'new',
      );
      expect(split, isNotNull);
      expect(split!.replaceId, 'b');
      expect(split.replacements, hasLength(2));
      expect(split.replacements[0].id, 'b');
      expect(split.replacements[0].durationSeconds, 420); // 7 whole minutes
      expect(split.replacements[0].targetDepth, 25);
      expect(split.replacements[1].id, 'new');
      // The second half keeps the original target, so it climbs back down.
      expect(split.replacements[1].targetDepth, 30);
      expect(split.replacements[1].durationSeconds, 1200 - 420);

      final after = [ordered[0], ...split.replacements];
      expect(_phaseOf(after, 'b'), SegmentPhase.ascent); // 30 -> 25
      expect(_startOf(after, 'new'), 25);
      expect(_phaseOf(after, 'new'), SegmentPhase.descent); // 25 -> 30
    });

    test('returns null when a half would be under 60s', () {
      final ordered = [_descent(), _bottom(seconds: 90)];
      expect(
        splitSegmentAt(
          ordered: ordered,
          timeSeconds: 121,
          depthMeters: 30,
          depthUnitScale: 1,
          idGen: () => 'new',
        ),
        isNull,
      );
    });

    test('appends a travel segment beyond the user span', () {
      final ordered = [_descent(), _bottom()];
      final split = splitSegmentAt(
        ordered: ordered,
        timeSeconds: 1320 + 200,
        depthMeters: 18.2,
        depthUnitScale: 1,
        idGen: () => 'new',
      );
      expect(split, isNotNull);
      expect(split!.replaceId, isEmpty); // append marker
      final appended = split.replacements.single;
      expect(appended.id, 'new');
      expect(appended.targetDepth, 18);
      expect(appended.durationSeconds, 180); // 200s rounds to 3 whole minutes
      expect(appended.tankId, 't1');

      final after = [...ordered, appended];
      expect(_startOf(after, 'new'), 30);
      expect(_phaseOf(after, 'new'), SegmentPhase.ascent);
    });
  });
}
