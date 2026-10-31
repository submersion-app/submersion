import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _ean36 = GasMix(o2: 36);

/// An OC descent to [depth] and a [minutes] hold there on [gas].
domain.DivePlan _plan({
  double depth = 35,
  int minutes = 5,
  GasMix gas = _ean36,
  double? altitude,
  WaterType? waterType,
}) => domain.DivePlan(
  id: 'env',
  name: 'Environment',
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  mode: domain.PlanMode.oc,
  altitude: altitude,
  waterType: waterType,
  problemSolvingMinutes: 0,
  tanks: [DiveTank(id: 'back', volume: 24, startPressure: 230, gasMix: gas)],
  segments: [
    PlanSegment.travel(
      id: 'down',
      fromDepth: 0,
      targetDepth: depth,
      tankId: 'back',
      gasMix: gas,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: depth,
      durationMinutes: minutes,
      tankId: 'back',
      gasMix: gas,
      order: 1,
    ),
  ],
);

Iterable<PlanIssue> _ofType(PlanOutcome outcome, PlanIssueType type) =>
    outcome.issues.where((i) => i.type == type);

void main() {
  const engine = PlanEngine();

  group('authored OC ppO2 in the plan water (issue #3913)', () {
    for (final altitude in [0.0, 3000.0]) {
      test('fresh water at $altitude m is a working-limit warning', () {
        final plan = _plan(altitude: altitude, waterType: WaterType.fresh);
        final expected =
            PlanEngine.environmentFor(plan).pressureAtDepth(35) * 0.36;
        final outcome = engine.compute(plan);
        final bottomRow = outcome.schedule.firstWhere(
          (r) => r.depthMeters == 35 && r.durationSeconds == 300,
        );

        expect(bottomRow.ppO2, closeTo(expected, 1e-12));
        expect(outcome.segmentOutcomes.last.maxPpO2, closeTo(expected, 1e-12));
        expect(_ofType(outcome, PlanIssueType.ppO2Critical), isEmpty);
        final high = _ofType(outcome, PlanIssueType.ppO2High).toList();
        expect(high, hasLength(2), reason: 'the descent and the hold');
        expect(high.last.value, closeTo(expected, 1e-12));
        expect(outcome.isDiveable, isTrue);
      });
    }

    test('salt water reads higher than the flat model, as the schedule', () {
      final plan = _plan();
      final expected =
          PlanEngine.environmentFor(plan).pressureAtDepth(35) * 0.36;
      expect(expected, greaterThan(1.62), reason: 'above the flat 1.62');
      final outcome = engine.compute(plan);

      final critical = _ofType(outcome, PlanIssueType.ppO2Critical).toList();
      expect(critical, hasLength(2));
      expect(critical.last.value, closeTo(expected, 1e-12));
      expect(outcome.isDiveable, isFalse);
    });

    test('CNS and OTU accrue at the plan water pressure', () {
      final plan = _plan(altitude: 3000, waterType: WaterType.fresh);
      final environment = PlanEngine.environmentFor(plan);
      final o2Calc = O2ToxicityCalculator(
        cnsMethod: const PlanEngineConfig().cnsMethod,
      );
      final outcome = engine.compute(plan);

      // A descent's pressure is linear in depth, so its mean is at mid-depth.
      final descentPpO2 = environment.pressureAtDepth(17.5) * 0.36;
      final holdPpO2 = environment.pressureAtDepth(35) * 0.36;
      final descentSeconds = outcome.segmentOutcomes.first.endRuntime;

      expect(
        outcome.segmentOutcomes.last.cns,
        closeTo(
          o2Calc.calculateCnsForSegment(descentPpO2, descentSeconds) +
              o2Calc.calculateCnsForSegment(holdPpO2, 300),
          1e-9,
        ),
      );
      expect(
        outcome.segmentOutcomes.last.otu,
        closeTo(
          o2Calc.calculateOtuForSegment(descentPpO2, descentSeconds) +
              o2Calc.calculateOtuForSegment(holdPpO2, 300),
          1e-9,
        ),
      );
    });
  });

  group('a ppO2 that still reads as its limit (issue #3913)', () {
    test('oxygen held at 6 m in salt water is not a critical issue', () {
      const oxygen = GasMix(o2: 100);
      final plan = _plan(depth: 6, gas: oxygen);
      final ppO2 = PlanEngine.environmentFor(plan).pressureAtDepth(6);
      expect(
        ppO2,
        greaterThan(1.6),
        reason: 'the flat model reads exactly 1.6',
      );
      expect(ppO2.toStringAsFixed(2), '1.60');

      final outcome = engine.compute(plan);

      expect(_ofType(outcome, PlanIssueType.ppO2Critical), isEmpty);
      expect(outcome.isDiveable, isTrue);
    });

    test('EAN40 at 30 m in salt water reads 1.61 and stays critical', () {
      const ean40 = GasMix(o2: 40);
      final plan = _plan(depth: 30, gas: ean40);
      final ppO2 = PlanEngine.environmentFor(plan).pressureAtDepth(30) * 0.40;
      expect(ppO2.toStringAsFixed(2), '1.61');

      final critical = _ofType(
        engine.compute(plan),
        PlanIssueType.ppO2Critical,
      ).toList();

      expect(critical, isNotEmpty);
      expect(critical.last.value, closeTo(ppO2, 1e-12));
    });

    domain.DivePlan planAtPpO2(double ppO2) {
      const ean32 = GasMix(o2: 32);
      final environment = PlanEngine.environmentFor(_plan());
      return _plan(depth: environment.depthAtPressure(ppO2 / 0.32), gas: ean32);
    }

    test('a gas reading 1.40 raises no working-limit warning', () {
      final outcome = engine.compute(planAtPpO2(1.403));

      expect(_ofType(outcome, PlanIssueType.ppO2High), isEmpty);
    });

    test('a gas reading 1.41 raises the working-limit warning', () {
      final outcome = engine.compute(planAtPpO2(1.406));

      expect(_ofType(outcome, PlanIssueType.ppO2High), isNotEmpty);
    });

    test('a loop setpoint gets no such tolerance', () {
      final outcome = engine.compute(
        _plan(
          gas: const GasMix(o2: 21),
        ).copyWith(mode: domain.PlanMode.ccr, setpointHigh: 1.403),
      );

      expect(outcome.segmentOutcomes.last.maxPpO2, closeTo(1.403, 1e-9));
      expect(_ofType(outcome, PlanIssueType.ppO2High), isNotEmpty);
    });
  });
}
