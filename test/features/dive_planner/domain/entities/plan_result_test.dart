import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';

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
}
