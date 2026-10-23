import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

// Gas switch depths follow the plan's water (issue #3566). On the flat
// 10 m per bar model EAN40 reaches 1.6 at exactly 30 m, but in the plan's
// own seawater it is already 1.606 there, which the schedule showed as 1.61.

const _ean40 = GasMix(o2: 40);
const _decoPpO2 = 1.6;

/// The 30 m stop every schedule here is built to include.
const _flatModStop = 30.0;

/// Deep enough on trimix that the ascent stops at 30 m, where the flat
/// EAN40 MOD sits.
domain.DivePlan _ocPlan({WaterType? waterType, int bottomMinutes = 25}) {
  const bottom = GasMix(o2: 18, he: 45);
  return domain.DivePlan(
    id: 'plan-1',
    name: 'Switch depth',
    gfLow: 30,
    gfHigh: 70,
    waterType: waterType,
    tanks: const [
      DiveTank(
        id: 'back',
        volume: 24,
        startPressure: 230,
        gasMix: bottom,
        role: TankRole.backGas,
      ),
      DiveTank(
        id: 'deco',
        volume: 11.1,
        startPressure: 207,
        gasMix: _ean40,
        role: TankRole.deco,
      ),
    ],
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 70,
        tankId: 'back',
        gasMix: bottom,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: 70,
        durationMinutes: bottomMinutes,
        tankId: 'back',
        gasMix: bottom,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 10, 23),
    updatedAt: DateTime(2026, 10, 23),
  );
}

domain.DivePlan _ccrPlan({double? altitude, int bottomMinutes = 45}) {
  const diluent = GasMix(o2: 18, he: 45);
  return domain.DivePlan(
    id: 'plan-2',
    name: 'Bailout switch depth',
    mode: domain.PlanMode.ccr,
    gfLow: 30,
    gfHigh: 70,
    altitude: altitude,
    tanks: const [
      DiveTank(
        id: 'dil',
        volume: 3,
        startPressure: 200,
        gasMix: diluent,
        role: TankRole.diluent,
      ),
      DiveTank(
        id: 'bo-bottom',
        volume: 11.1,
        startPressure: 207,
        gasMix: diluent,
        role: TankRole.bailout,
      ),
      DiveTank(
        id: 'bo',
        volume: 11.1,
        startPressure: 207,
        gasMix: _ean40,
        role: TankRole.bailout,
      ),
    ],
    segments: [
      PlanSegment.travel(
        id: 'seg-1',
        fromDepth: 0,
        targetDepth: 70,
        tankId: 'dil',
        gasMix: diluent,
        order: 0,
        ratePerMinute: 18,
      ),
      PlanSegment.hold(
        id: 'seg-2',
        depth: 70,
        durationMinutes: bottomMinutes,
        tankId: 'dil',
        gasMix: diluent,
        order: 1,
      ),
    ],
    createdAt: DateTime(2026, 10, 23),
    updatedAt: DateTime(2026, 10, 23),
  );
}

bool _isEan40(double fO2) => (fO2 - 0.40).abs() < 1e-6;

void _expectEan40WithinLimit(List<PlanScheduleRow> rows) {
  final ean40Rows = rows.where((r) => _isEan40(r.gasFO2)).toList();
  expect(ean40Rows, isNotEmpty, reason: 'the ascent switches to EAN40');
  // Read the way the table shows it: a switch may sit up to
  // gasSwitchPpO2Tolerance above the limit, as long as it reads 1.60.
  for (final row in ean40Rows) {
    expect(
      double.parse(row.ppO2.toStringAsFixed(2)),
      lessThanOrEqualTo(_decoPpO2),
      reason: 'EAN40 at ${row.depthMeters} m',
    );
  }
}

void main() {
  group('PlanEngine', () {
    test('in salt water the 30 m stop is breathed on back gas', () {
      final outcome = const PlanEngine().compute(_ocPlan());

      final stop30 = outcome.stops.singleWhere(
        (s) => s.depthMeters == _flatModStop,
      );
      expect(stop30.tankId, 'back');
      expect(
        outcome.stops.firstWhere((s) => s.tankId == 'deco').depthMeters,
        27,
      );
    });

    test('no schedule line shows EAN40 above the deco ppO2 limit', () {
      final outcome = const PlanEngine().compute(_ocPlan());
      _expectEan40WithinLimit(outcome.schedule);
    });

    test('in salt water oxygen is still breathed from the 6 m stop', () {
      // 1.603 bar there, which reads 1.60: within gasSwitchPpO2Tolerance.
      const o2 = GasMix(o2: 100);
      final base = _ocPlan();
      final plan = base.copyWith(
        tanks: [
          ...base.tanks,
          const DiveTank(
            id: 'o2',
            volume: 11.1,
            startPressure: 207,
            gasMix: o2,
            role: TankRole.deco,
          ),
        ],
      );
      final outcome = const PlanEngine().compute(plan);

      final stop6 = outcome.stops.singleWhere((s) => s.depthMeters == 6);
      expect(stop6.tankId, 'o2');
      for (final row in outcome.schedule) {
        expect(
          double.parse(row.ppO2.toStringAsFixed(2)),
          lessThanOrEqualTo(_decoPpO2),
          reason: '${row.gasFO2} at ${row.depthMeters} m',
        );
      }
    });

    test('in fresh water EAN40 is breathed from the 30 m stop', () {
      // Fresh water weighs less: a longer dive to bring the first stop
      // down to 30 m.
      final outcome = const PlanEngine().compute(
        _ocPlan(waterType: WaterType.fresh, bottomMinutes: 40),
      );

      final stop30 = outcome.stops.singleWhere(
        (s) => s.depthMeters == _flatModStop,
      );
      expect(stop30.tankId, 'deco');
      _expectEan40WithinLimit(outcome.schedule);
    });
  });

  group('BailoutSolver', () {
    test('no worst-case line shows EAN40 above the deco ppO2 limit', () {
      final outcome = const BailoutSolver().solve(_ccrPlan())!;
      expect(
        outcome.worstCaseRows.map((r) => r.depthMeters),
        contains(_flatModStop),
      );
      _expectEan40WithinLimit(outcome.worstCaseRows);
    });

    test('an altitude of 0 is the same plan as no altitude', () {
      // PlanEngine treats altitude <= 0 as unset (1.0 bar surface); the
      // bailout schedule must be computed in the same water.
      final unset = const BailoutSolver().solve(_ccrPlan())!;
      final zero = const BailoutSolver().solve(_ccrPlan(altitude: 0))!;
      expect(zero.worstCaseRows, unset.worstCaseRows);
    });
  });

  group('PlanCalculatorService', () {
    PlanCalculatorService calculator() =>
        PlanCalculatorService(gfLow: 30, gfHigh: 70);

    test('in salt water the 30 m stop is breathed on back gas', () {
      final plan = _ocPlan();
      final result = calculator().calculatePlan(
        segments: plan.segments,
        tanks: plan.tanks,
        sacRate: 15,
        environment: DiveEnvironment.forConditions(waterType: WaterType.salt),
      );

      final stop30 = result.decoSchedule.singleWhere(
        (s) => s.depth == _flatModStop,
      );
      expect(stop30.gasMix.o2, closeTo(18, 1e-6));
    });

    test('in fresh water EAN40 is breathed from the 30 m stop', () {
      final plan = _ocPlan(bottomMinutes: 40);
      final result = calculator().calculatePlan(
        segments: plan.segments,
        tanks: plan.tanks,
        sacRate: 15,
        environment: DiveEnvironment.forConditions(waterType: WaterType.fresh),
      );

      final stop30 = result.decoSchedule.singleWhere(
        (s) => s.depth == _flatModStop,
      );
      expect(stop30.gasMix.o2, closeTo(40, 1e-6));
    });
  });
}
