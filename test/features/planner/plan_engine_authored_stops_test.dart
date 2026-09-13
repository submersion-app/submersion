import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);
const _airTank = DiveTank(
  id: 'tank-1',
  volume: 11.1,
  startPressure: 207.0,
  gasMix: _air,
);

PlanSegment _travel(String id, double from, double to, int order) =>
    PlanSegment.travel(
      id: id,
      fromDepth: from,
      targetDepth: to,
      tankId: 'tank-1',
      gasMix: _air,
      ratePerMinute: 9.0,
      order: order,
    );

PlanSegment _hold(String id, double depth, int minutes, int order) =>
    PlanSegment.hold(
      id: id,
      depth: depth,
      durationMinutes: minutes,
      tankId: 'tank-1',
      gasMix: _air,
      order: order,
    );

domain.DivePlan _plan(List<PlanSegment> segments) => domain.DivePlan(
  id: 'plan-1',
  name: 'TTS invariants',
  gfLow: 40,
  gfHigh: 80,
  lastStopDepth: 3.0,
  segments: segments,
  tanks: const [_airTank],
  createdAt: DateTime(2026, 7, 5),
  updatedAt: DateTime(2026, 7, 5),
);

/// The one definition of TTS: everything after the last authored segment.
void _expectTtsIsTimeAfterAuthoredSegments(PlanOutcome outcome) {
  final authoredEnd = outcome.segmentOutcomes.last.endRuntime;
  expect(outcome.ttsAtBottom, outcome.runtimeSeconds - authoredEnd);

  // And it is exactly what the printed schedule adds up to after the
  // authored rows: travel to the first stop, the stops, the travel between
  // them and the final ascent.
  final tail = outcome.schedule.where((r) => r.runtimeSeconds > authoredEnd);
  final tailSeconds = tail.fold(0, (sum, r) => sum + r.durationSeconds);
  expect(outcome.ttsAtBottom, tailSeconds);
}

void main() {
  const engine = PlanEngine();

  final shapes = <String, List<PlanSegment>>{
    'bottom only': [_travel('d', 0, 45, 0), _hold('b', 45, 25, 1)],
    'wander shallower before the ascent': [
      _travel('d', 0, 45, 0),
      _hold('b', 45, 20, 1),
      _travel('w1', 45, 40, 2),
      _hold('w2', 40, 5, 3),
    ],
    'second working level': [
      _travel('d', 0, 45, 0),
      _hold('b', 45, 20, 1),
      _travel('u', 45, 30, 2),
      _hold('l2', 30, 10, 3),
    ],
    'authored stops after the bottom': [
      _travel('d', 0, 45, 0),
      _hold('b', 45, 25, 1),
      _travel('a1', 45, 9, 2),
      _hold('s1', 9, 15, 3),
      _travel('a2', 9, 6, 4),
      _hold('s2', 6, 30, 5),
    ],
    'saw-tooth bottom ending on a shallow hold': [
      _travel('d', 0, 51, 0),
      _hold('b', 51, 5, 1),
      _travel('u1', 51, 46, 2),
      _hold('h1', 46, 3, 3),
      _travel('d2', 46, 49, 4),
      _hold('h2', 49, 2, 5),
      _travel('u2', 49, 33, 6),
      _hold('h3', 33, 1, 7),
      _travel('u3', 33, 24, 8),
      _hold('h4', 24, 4, 9),
    ],
  };

  group('TTS is the time after the last authored segment', () {
    for (final entry in shapes.entries) {
      test(entry.key, () {
        _expectTtsIsTimeAfterAuthoredSegments(
          engine.compute(_plan(entry.value)),
        );
      });
    }

    test('is never the direct ascent from the deepest leg', () {
      final direct = engine.compute(_plan(shapes['bottom only']!));
      final twoLevels = engine.compute(_plan(shapes['second working level']!));
      expect(twoLevels.ttsAtBottom, isNot(direct.ttsAtBottom));
    });

    test('runtime is always authored time plus TTS', () {
      for (final segments in shapes.values) {
        final outcome = engine.compute(_plan(segments));
        final authored = segments.fold(0, (s, seg) => s + seg.durationSeconds);
        expect(outcome.runtimeSeconds, authored + outcome.ttsAtBottom);
      }
    });
  });

  test('deco time counts authored stop holds plus computed stops', () {
    final outcome = engine.compute(
      _plan(shapes['authored stops after the bottom']!),
    );
    final computed = outcome.stops.fold(0, (sum, s) => sum + s.durationSeconds);
    expect(outcome.totalDecoSeconds, (15 + 30) * 60 + computed);
  });
}
