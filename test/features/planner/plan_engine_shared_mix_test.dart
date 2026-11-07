import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// Deco cylinders carrying the same mix share the ascent breathed from it
/// instead of the first one taking all of it (#4138).
const _tx = GasMix(o2: 21, he: 35);
const _ean50 = GasMix(o2: 50);

DiveTank _stage(String id, {double volume = 7, double pressure = 200}) =>
    DiveTank(
      id: id,
      volume: volume,
      startPressure: pressure,
      gasMix: _ean50,
      role: TankRole.deco,
    );

domain.DivePlan _plan(List<DiveTank> stages) => domain.DivePlan(
  id: 'plan-4138-oc',
  name: 'two stages',
  mode: domain.PlanMode.oc,
  gfLow: 50,
  gfHigh: 80,
  problemSolvingMinutes: 0,
  sacBottom: 20,
  sacDeco: 16,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  tanks: [
    const DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _tx),
    ...stages,
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 50,
      tankId: 'back',
      gasMix: _tx,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 50,
      durationMinutes: 30,
      tankId: 'back',
      gasMix: _tx,
      order: 1,
    ),
  ],
);

PlanTankUsage _usage(PlanOutcome outcome, String id) =>
    outcome.tankUsages.firstWhere((u) => u.tankId == id);

void main() {
  const engine = PlanEngine();

  test('two identical stages of one mix share the deco evenly', () {
    final outcome = engine.compute(_plan([_stage('d1'), _stage('d2')]));
    final d1 = _usage(outcome, 'd1');
    final d2 = _usage(outcome, 'd2');

    expect(d1.litersUsed, greaterThan(0));
    expect(d1.litersUsed, closeTo(d2.litersUsed, 1e-6));
    expect(d1.remainingPressure, closeTo(d2.remainingPressure!, 1e-6));
  });

  test('the pair breathes what one stage of that mix would', () {
    final single = engine.compute(_plan([_stage('d1', volume: 14)]));
    final pair = engine.compute(_plan([_stage('d1'), _stage('d2')]));

    expect(
      _usage(pair, 'd1').litersUsed + _usage(pair, 'd2').litersUsed,
      closeTo(_usage(single, 'd1').litersUsed, 1e-6),
    );
    expect(
      _usage(pair, 'back').litersUsed,
      closeTo(_usage(single, 'back').litersUsed, 1e-6),
    );
  });

  test('a stage an authored leg already breathed is drawn last', () {
    // Ten minutes on d1 at 21 m before the computed ascent: the deco draws
    // d2 first, so the pair still ends level.
    final base = _plan([_stage('d1'), _stage('d2')]);
    final plan = base.copyWith(
      segments: [
        ...base.segments,
        PlanSegment.travel(
          id: 'up',
          fromDepth: 50,
          targetDepth: 21,
          tankId: 'back',
          gasMix: _tx,
          order: 2,
          ratePerMinute: 9,
        ),
        PlanSegment.hold(
          id: 'on-d1',
          depth: 21,
          durationMinutes: 10,
          tankId: 'd1',
          gasMix: _ean50,
          order: 3,
        ),
      ],
    );
    final outcome = engine.compute(plan);
    final d1 = _usage(outcome, 'd1');
    final d2 = _usage(outcome, 'd2');

    expect(d1.litersUsed, closeTo(d2.litersUsed, 1e-6));
    expect(d1.remainingPressure, closeTo(d2.remainingPressure!, 1e-6));
  });

  test('a stage too small for its share runs out with its twin', () {
    final outcome = engine.compute(
      _plan([
        _stage('d1', volume: 1, pressure: 50),
        _stage('d2', volume: 1, pressure: 50),
      ]),
    );
    final out = outcome.issues
        .where((i) => i.type == PlanIssueType.gasOut)
        .toList();

    expect(out.map((i) => i.tankId), containsAll(['d1', 'd2']));
    // Each placed on its own draw, where that cylinder empties.
    for (final issue in out.where((i) => i.tankId != 'back')) {
      expect(issue.atRuntime, isNotNull);
    }
  });
}
