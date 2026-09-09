import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

PlanResult _result({int totalRuntime = 0, int ndlAtBottom = 0}) {
  return PlanResult(
    totalRuntime: totalRuntime,
    ttsAtBottom: 0,
    ndlAtBottom: ndlAtBottom,
    maxDepth: 0,
    maxCeiling: 0,
    avgDepth: 0,
    decoSchedule: const [],
    gasConsumptions: const [],
    warnings: const [],
    endTissueState: const [],
    segmentResults: const {},
    cnsEnd: 0,
    otuTotal: 0,
    maxPpO2: 0,
    hasDecoObligation: false,
  );
}

GasConsumption _gas({
  double? startPressure,
  double? remainingPressure,
  double? minGasReserve,
  bool reserveViolation = false,
}) {
  return GasConsumption(
    tankId: 't1',
    tankName: 'AL80',
    gasMix: const GasMix(),
    gasUsedLiters: 1500.0,
    gasUsedBar: 135.0,
    startPressure: startPressure,
    remainingPressure: remainingPressure,
    percentUsed: 67.5,
    minGasReserve: minGasReserve,
    reserveViolation: reserveViolation,
  );
}

void main() {
  group('PlanResult formatting', () {
    test('runtimeFormatted includes hours when totalRuntime >= 3600', () {
      expect(_result(totalRuntime: 3661).runtimeFormatted, '01:01:01');
    });

    test(
      'ndlFormatted returns >99 min when ndlAtBottom exceeds 99 minutes',
      () {
        expect(_result(ndlAtBottom: 100 * 60).ndlFormatted, '>99 min');
      },
    );
  });

  group('GasConsumption', () {
    test('stores startPressure as double', () {
      final gas = _gas(startPressure: 207.0);
      expect(gas.startPressure, 207.0);
    });

    test('stores remainingPressure as double', () {
      final gas = _gas(remainingPressure: 72.0);
      expect(gas.remainingPressure, 72.0);
    });

    test('stores minGasReserve as double', () {
      final gas = _gas(minGasReserve: 50.0);
      expect(gas.minGasReserve, 50.0);
    });

    test('remainingFormatted returns rounded bar string', () {
      final gas = _gas(remainingPressure: 72.3);
      expect(gas.remainingFormatted, '72bar');
    });

    test('remainingFormatted returns -- when null', () {
      final gas = _gas();
      expect(gas.remainingFormatted, '--');
    });

    test('remainingFormatted returns EMPTY when zero', () {
      final gas = _gas(remainingPressure: 0.0);
      expect(gas.remainingFormatted, 'EMPTY');
    });

    test('remainingFormatted returns EMPTY when negative', () {
      final gas = _gas(remainingPressure: -5.0);
      expect(gas.remainingFormatted, 'EMPTY');
    });

    test('reserveViolation defaults to false', () {
      final gas = _gas(minGasReserve: 50.0);
      expect(gas.reserveViolation, isFalse);
    });

    test('reserveViolation can be set to true', () {
      final gas = _gas(minGasReserve: 50.0, reserveViolation: true);
      expect(gas.reserveViolation, isTrue);
    });

    test('percentFormatted returns integer percentage', () {
      final gas = _gas();
      expect(gas.percentFormatted, '68%');
    });
  });

  group('PlanSegment equality', () {
    PlanSegment segment({double targetDepth = 30.0}) => PlanSegment(
      id: 'seg-1',
      targetDepth: targetDepth,
      durationSeconds: 180,
      tankId: 't1',
      gasMix: const GasMix(),
    );

    test('segments with identical fields are equal', () {
      expect(segment(), equals(segment()));
      expect(segment().hashCode, segment().hashCode);
    });

    test('segments differing only in targetDepth are not equal', () {
      expect(segment(), isNot(equals(segment(targetDepth: 18.0))));
    });
  });

  group('DivePlanState', () {
    final createdAt = DateTime(2026, 1, 1, 9);

    PlanSegment segment(double targetDepth) => PlanSegment(
      id: 's$targetDepth',
      targetDepth: targetDepth,
      durationSeconds: 60,
      tankId: 't1',
      gasMix: const GasMix(),
    );

    DivePlanState state({
      List<PlanSegment> segments = const [],
      double intermediateAscentRate = 6.0,
      double shallowAscentRate = 3.0,
      double finalAscentRate = 1.0,
      double lastStopDepth = 3.0,
      WaterType? waterType,
      double? salinityPpt,
    }) => DivePlanState(
      id: 'plan-1',
      name: 'Plan',
      segments: segments,
      tanks: const [],
      intermediateAscentRate: intermediateAscentRate,
      shallowAscentRate: shallowAscentRate,
      finalAscentRate: finalAscentRate,
      lastStopDepth: lastStopDepth,
      waterType: waterType,
      salinityPpt: salinityPpt,
      createdAt: createdAt,
      updatedAt: createdAt,
    );

    test('maxDepth is 0 for a plan with no segments', () {
      expect(state().maxDepth, 0);
    });

    test('maxDepth is the deepest target across all segments', () {
      final plan = state(
        segments: [segment(12), segment(40), segment(40), segment(18)],
      );

      expect(plan.maxDepth, 40.0);
    });

    test('maxDepth ignores where the profile ends', () {
      // The last segment returns to the surface; the bottom is still 30 m.
      final plan = state(segments: [segment(30), segment(30), segment(0)]);

      expect(plan.maxDepth, 30.0);
    });

    test('states with identical fields are equal', () {
      expect(state(), equals(state()));
      expect(state().hashCode, state().hashCode);
    });

    test('a different intermediateAscentRate breaks equality', () {
      expect(state(), isNot(equals(state(intermediateAscentRate: 9.0))));
    });

    test('a different shallowAscentRate breaks equality', () {
      expect(state(), isNot(equals(state(shallowAscentRate: 6.0))));
    });

    test('a different finalAscentRate breaks equality', () {
      expect(state(), isNot(equals(state(finalAscentRate: 3.0))));
    });

    test('a different lastStopDepth breaks equality', () {
      expect(state(), isNot(equals(state(lastStopDepth: 6.0))));
    });

    test('a different waterType breaks equality', () {
      expect(state(), isNot(equals(state(waterType: WaterType.salt))));
    });

    test('a different salinityPpt breaks equality', () {
      expect(state(), isNot(equals(state(salinityPpt: 20))));
    });
  });
}
