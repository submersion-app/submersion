import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix(o2: 21);

domain.DivePlan _airPlan({
  double depth = 45.0,
  int minutes = 25,
  List<DiveTank>? tanks,
  double reservePressure = 50.0,
}) {
  final tankList =
      tanks ??
      const [
        DiveTank(id: 'tank-1', volume: 24.0, startPressure: 232, gasMix: _air),
      ];
  final tankId = tankList.first.id;
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Issues test',
    gfLow: 40,
    gfHigh: 80,
    reservePressure: reservePressure,
    tanks: tankList,
    segments: [
      PlanSegment.descent(
        id: 'seg-1',
        targetDepth: depth,
        tankId: tankId,
        gasMix: _air,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'seg-2',
        depth: depth,
        durationMinutes: minutes,
        tankId: tankId,
        gasMix: _air,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

Iterable<PlanIssueType> _types(PlanOutcome outcome) =>
    outcome.issues.map((i) => i.type);

void main() {
  const engine = PlanEngine();

  group('PlanEngine issues', () {
    test('air at 70 m raises critical ppO2', () {
      final outcome = engine.compute(_airPlan(depth: 70.0, minutes: 10));
      expect(_types(outcome), contains(PlanIssueType.ppO2Critical));
      expect(outcome.isDiveable, isFalse);
    });

    test('hypoxic mix at the surface raises hypoxicGas', () {
      const tx1070 = GasMix(o2: 10, he: 70);
      const tank = DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 232,
        gasMix: tx1070,
      );
      final plan = domain.DivePlan(
        id: 'plan-1',
        name: 'Hypoxic',
        gfLow: 40,
        gfHigh: 80,
        tanks: const [tank],
        segments: [
          PlanSegment.descent(
            id: 'seg-1',
            targetDepth: 60.0,
            tankId: 'back',
            gasMix: tx1070,
            order: 0,
          ),
        ],
        createdAt: DateTime(2026, 7, 5),
        updatedAt: DateTime(2026, 7, 5),
      );
      final outcome = engine.compute(plan);
      expect(_types(outcome), contains(PlanIssueType.hypoxicGas));
    });

    test('air at 45 m raises END and critical gas density', () {
      final outcome = engine.compute(_airPlan(depth: 45.0));
      expect(_types(outcome), contains(PlanIssueType.endExceeded));
      // python3: air density at 45 m = 6.598 g/L > 6.2 hard limit.
      expect(_types(outcome), contains(PlanIssueType.gasDensityCritical));
    });

    test('tiny tank runs out of gas', () {
      final outcome = engine.compute(
        _airPlan(
          tanks: const [
            DiveTank(
              id: 'tank-1',
              volume: 3.0,
              startPressure: 100,
              gasMix: _air,
            ),
          ],
        ),
      );
      expect(_types(outcome), contains(PlanIssueType.gasOut));
      expect(outcome.isDiveable, isFalse);
    });

    test('high reserve raises reserve violation without gasOut', () {
      final outcome = engine.compute(
        _airPlan(depth: 30.0, minutes: 10, reservePressure: 200.0),
      );
      expect(_types(outcome), contains(PlanIssueType.gasReserveViolation));
      expect(_types(outcome), isNot(contains(PlanIssueType.gasOut)));
    });

    test('deco without a deco gas raises the alert; adding one clears it', () {
      final without = engine.compute(_airPlan());
      expect(_types(without), contains(PlanIssueType.ndlExceededNoDecoGas));

      final withDeco = engine.compute(
        _airPlan(
          tanks: const [
            DiveTank(
              id: 'tank-1',
              volume: 24.0,
              startPressure: 232,
              gasMix: _air,
            ),
            DiveTank(
              id: 'ean50',
              volume: 11.1,
              startPressure: 207,
              gasMix: GasMix(o2: 50),
              role: TankRole.deco,
            ),
          ],
        ),
      );
      expect(
        _types(withDeco),
        isNot(contains(PlanIssueType.ndlExceededNoDecoGas)),
      );
    });

    test('issues are sorted most severe first', () {
      final outcome = engine.compute(_airPlan(depth: 70.0, minutes: 20));
      final severities = outcome.issues.map((i) => i.severity.index).toList();
      for (var i = 1; i < severities.length; i++) {
        expect(severities[i - 1], greaterThanOrEqualTo(severities[i]));
      }
      expect(outcome.issues.first.severity, PlanIssueSeverity.critical);
    });
  });

  group('PlanEngine consumption', () {
    test('no-deco plan matches hand-computed liters', () {
      // 30 m / 10 min air, GF 40/80: no stops.
      // descent 100 s at avg 15 m (2.5 bar) on bottom SAC 15: 62.5 L
      // bottom 10 min at 4.0 bar on 15: 600 L
      // direct ascent 200 s at avg 15 m (2.5 bar) on deco SAC 12: 100 L
      // total 762.5 L
      final outcome = engine.compute(_airPlan(depth: 30.0, minutes: 10));
      expect(outcome.stops, isEmpty);
      expect(outcome.tankUsages.single.litersUsed, closeTo(762.5, 1.0));
      // Compressibility: remaining is BELOW the ideal-gas figure.
      const idealRemaining = 232 - 762.5 / 24.0;
      expect(
        outcome.tankUsages.single.remainingPressure!,
        lessThan(idealRemaining + 0.01),
      );
    });

    test('deco stops charge the deco tank, not the back gas', () {
      final outcome = engine.compute(
        _airPlan(
          tanks: const [
            DiveTank(
              id: 'back',
              volume: 24.0,
              startPressure: 232,
              gasMix: _air,
            ),
            DiveTank(
              id: 'ean50',
              volume: 11.1,
              startPressure: 207,
              gasMix: GasMix(o2: 50),
              role: TankRole.deco,
            ),
          ],
        ),
      );
      expect(outcome.stops, isNotEmpty);
      final ean50 = outcome.tankUsages.firstWhere((u) => u.tankId == 'ean50');
      expect(ean50.litersUsed, greaterThan(0));
    });
  });
}
