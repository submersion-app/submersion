import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

/// The plan switches to each gas at that cylinder's MOD (issue #3567): the
/// diver's override when there is one, otherwise the default for its role
/// at the plan's own ppO2 limits.
///
/// The bottom gas is a 15/55: hypoxic at the surface, but its ppO2 at 70 m
/// stays under 1.4, so the only ppO2 issues are the ones these tests cause.
const _back = GasMix(o2: 15, he: 55);
const _ean40 = GasMix(o2: 40);

domain.DivePlan _plan({
  double? ean40Mod,
  bool ean40Travel = false,
  double? ppO2Deco,
  double ean40Start = 207,
}) => domain.DivePlan(
  id: 'plan-mod',
  name: 'MOD override',
  gfLow: 30,
  gfHigh: 70,
  ppO2Deco: ppO2Deco,
  tanks: [
    const DiveTank(id: 'back', volume: 24, startPressure: 232, gasMix: _back),
    DiveTank(
      id: 'ean40',
      volume: 11.1,
      startPressure: ean40Start,
      gasMix: _ean40,
      isTravelGas: ean40Travel,
      decoSwitchDepth: ean40Mod,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 's1',
      fromDepth: 0,
      targetDepth: 70,
      tankId: 'back',
      gasMix: _back,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 's2',
      depth: 70,
      durationMinutes: 25,
      tankId: 'back',
      gasMix: _back,
      order: 1,
    ),
  ],
  createdAt: DateTime(2026, 10, 22),
  updatedAt: DateTime(2026, 10, 22),
);

/// The deepest stop breathed from EAN40, in metres.
double _deepestEan40Stop(PlanOutcome outcome) => outcome.stops
    .where((s) => s.tankId == 'ean40')
    .map((s) => s.depthMeters)
    .reduce((a, b) => a > b ? a : b);

/// The deepest decompression stop of the whole ascent.
double _firstStop(PlanOutcome outcome) =>
    outcome.stops.map((s) => s.depthMeters).reduce((a, b) => a > b ? a : b);

void main() {
  const engine = PlanEngine();

  test('the plan reaches stops deep enough to tell the depths apart', () {
    // Guards the other tests: they need stops below 30 m.
    expect(_firstStop(engine.compute(_plan())), greaterThan(30));
  });

  test('without an override, EAN40 as deco gas joins below 30 m (1.6)', () {
    // The default switch is measured in the plan's seawater (issue #3566):
    // EAN40 at 30 m is 1.606 bar and reads 1.61, so the deepest stop on it
    // is 27 m.
    expect(_deepestEan40Stop(engine.compute(_plan())), 27);
  });

  test('a 21 m override switches to EAN40 at 21 m, not 30 m', () {
    expect(_deepestEan40Stop(engine.compute(_plan(ean40Mod: 21))), 21);
  });

  test('a lower deco ppO2 moves the default switch depth', () {
    // 1.4 / 0.40 = 3.5 bar: 25 m, so the deepest stop on it is 24 m.
    expect(_deepestEan40Stop(engine.compute(_plan(ppO2Deco: 1.4))), 24);
  });

  test('an override is kept when the deco ppO2 changes', () {
    expect(
      _deepestEan40Stop(engine.compute(_plan(ean40Mod: 21, ppO2Deco: 1.4))),
      21,
    );
  });

  test('a stage (travel gas) uses the bottom limit: 25 m at 1.4', () {
    expect(_deepestEan40Stop(engine.compute(_plan(ean40Travel: true))), 24);
  });

  test('an override deeper than the limit is used, and reported', () {
    bool stopsAt33(PlanOutcome o) => o.stops.any((s) => s.depthMeters == 33);
    // Without it the 33 m stop is still on back gas; breathing EAN40 from
    // 33 m instead clears that stop altogether.
    expect(stopsAt33(engine.compute(_plan())), isTrue);
    final outcome = engine.compute(_plan(ean40Mod: 33));
    expect(stopsAt33(outcome), isFalse);
    final critical = outcome.issues.where(
      (i) => i.type == PlanIssueType.ppO2Critical,
    );
    expect(critical, isNotEmpty);
    // 0.40 x the ambient pressure at 33 m in the plan's own water, as the
    // schedule measures it.
    final ambient = PlanEngine.environmentFor(_plan()).pressureAtDepth(33);
    expect(critical.first.value, closeTo(0.40 * ambient, 1e-9));
    expect(critical.first.atDepth, 33);
    expect(critical.first.threshold, 1.6);
  });

  test('a reported override takes its place in severity order', () {
    // A short-filled EAN40 adds a gas issue of lower severity; the critical
    // MOD issue must still come ahead of it.
    final outcome = engine.compute(_plan(ean40Mod: 33, ean40Start: 70));
    final severities = outcome.issues.map((i) => i.severity).toList();
    expect(severities, contains(PlanIssueSeverity.critical));
    expect(
      severities.any((s) => s != PlanIssueSeverity.critical),
      isTrue,
      reason: 'needs a lower-severity issue to order against',
    );
    expect(
      severities,
      [...severities]..sort((a, b) => b.index.compareTo(a.index)),
    );
  });

  test('an override at the flat default is reported in the plan water', () {
    // The editor shows EAN40's default as 30 m (1.60 on a MOD table), but
    // the schedule's ppO2 at 30 m in the plan's water is higher; typing 30
    // must not switch there unreported (issue #3566).
    final plan = _plan(ean40Mod: 30);
    final ppO2 = 0.40 * PlanEngine.environmentFor(plan).pressureAtDepth(30);
    expect(ppO2, greaterThan(1.605), reason: 'the plan water must be salty');
    final reported = engine
        .compute(plan)
        .issues
        .where((i) => i.type == PlanIssueType.ppO2Critical);
    expect(reported, isNotEmpty);
    expect(reported.first.value, closeTo(ppO2, 1e-9));
  });

  test('an override within the limit raises nothing', () {
    final outcome = engine.compute(_plan(ean40Mod: 21));
    expect(
      outcome.issues.where(
        (i) =>
            i.type == PlanIssueType.ppO2Critical ||
            i.type == PlanIssueType.ppO2High,
      ),
      isEmpty,
    );
  });
}
