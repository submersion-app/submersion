import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_edit_controller.dart';
import 'package:submersion/features/planner/presentation/chart/plan_chart_geometry.dart';

const _gas = GasMix(o2: 21);
const _ean50 = GasMix(o2: 50);

PlanSegment _descent({String id = 'd', double to = 30, int seconds = 120}) =>
    PlanSegment(
      id: id,
      type: SegmentType.descent,
      startDepth: 0,
      endDepth: to,
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
  type: SegmentType.bottom,
  startDepth: depth,
  endDepth: depth,
  durationSeconds: seconds,
  tankId: 't1',
  gasMix: _gas,
  order: order,
);

PlanSegment _gasSwitch({String id = 'g', double depth = 21, int order = 2}) =>
    PlanSegment(
      id: id,
      type: SegmentType.gasSwitch,
      startDepth: depth,
      endDepth: depth,
      durationSeconds: 60,
      tankId: 't2',
      gasMix: _ean50,
      switchToTankId: 't2',
      order: order,
    );

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

    test('gas switch vertices are not draggable but keep time', () {
      final vertices = planVertices([_descent(), _bottom(), _gasSwitch()]);
      expect(vertices[2].draggable, isFalse);
      expect(vertices[2].timeSeconds, 1380);
      expect(vertices[0].draggable, isTrue);
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
    test('deepening the bottom vertex retypes and follows next start', () {
      final ordered = [_descent(), _bottom(), _bottom(id: 'b2', order: 2)];
      final result = dragVertex(
        ordered: ordered,
        vertexIndex: 1,
        newDepthMeters: 35.4,
        newTimeSeconds: 1320,
        depthUnitScale: 1,
      );
      final updated = Map.fromEntries(
        result.updates.map((u) => MapEntry(u.$1, u.$2)),
      );
      // Depth snapped to whole meters; segment b now slopes down -> descent.
      expect(updated['b']!.endDepth, 35);
      expect(updated['b']!.type, SegmentType.descent);
      // Next segment start follows.
      expect(updated['b2']!.startDepth, 35);
      expect(updated['b2']!.type, SegmentType.ascent);
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
      expect(b.type, SegmentType.bottom);

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
      expect(d.endDepth, closeTo(99 / 3.2808, 0.001));
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
      expect(split.replacements[0].endDepth, 25);
      expect(split.replacements[0].type, SegmentType.ascent); // 30 -> 25
      expect(split.replacements[1].id, 'new');
      expect(split.replacements[1].startDepth, 25);
      expect(split.replacements[1].durationSeconds, 1200 - 420);
      expect(split.replacements[1].type, SegmentType.descent); // 25 -> 30
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
      expect(appended.startDepth, 30);
      expect(appended.endDepth, 18);
      expect(appended.durationSeconds, 180); // 200s rounds to 3 whole minutes
      expect(appended.type, SegmentType.ascent);
      expect(appended.tankId, 't1');
    });
  });
}
