import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/units.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

void main() {
  group('PlanCalculatorService reserve pressure', () {
    late PlanCalculatorService calculator;

    setUp(() {
      calculator = PlanCalculatorService();
    });

    /// Creates a simple 18m/40min dive on air with an AL80 starting at
    /// 200 bar and returns the [PlanResult] for the given [reservePressure]
    /// (in bar, as stored internally).
    PlanResult calculateWithReserve(double reservePressureBar) {
      const tankId = 'tank-1';
      const gasMix = GasMix(o2: 21, he: 0);

      const tank = DiveTank(
        id: tankId,
        name: 'AL80',
        volume: 11.1,
        workingPressure: 207,
        startPressure: 200,
        gasMix: gasMix,
        order: 0,
      );

      final segments = calculator.createSimplePlan(
        maxDepth: 18,
        bottomTimeMinutes: 40,
        tank: tank,
      );

      return calculator.calculatePlan(
        segments: segments,
        tanks: [tank],
        sacRate: 15,
        reservePressure: reservePressureBar,
      );
    }

    /// Converts a psi value to bar, simulating what the UI does when the
    /// user enters a reserve in psi.
    double psiToBar(double psi) =>
        PressureUnit.psi.convert(psi, PressureUnit.bar);

    test('remaining pressure is positive for the test dive profile', () {
      final result = calculateWithReserve(0);
      final consumption = result.gasConsumptions.first;

      expect(consumption.remainingPressure, isNotNull);
      expect(consumption.remainingPressure!, greaterThan(0));
    });

    test(
      'no gasLow warning when reserve entered as psi is below remaining',
      () {
        // This profile ends with ~35 bar (~508 psi) remaining.
        // A user entering 500 psi as reserve (≈ 34.47 bar) should see
        // NO warning, because 35 bar remaining > 34.47 bar reserve.
        final result = calculateWithReserve(psiToBar(500));
        final gasLowWarnings = result.warnings
            .where((w) => w.type == PlanWarningType.gasLow)
            .toList();

        expect(gasLowWarnings, isEmpty);
        expect(result.gasConsumptions.first.reserveViolation, isFalse);
      },
    );

    test('gasLow warning when reserve entered as psi is above remaining', () {
      // Same profile (~508 psi remaining). A user entering 600 psi as
      // reserve (≈ 41.37 bar) should trigger a warning.
      final reserveBar = psiToBar(600);
      final result = calculateWithReserve(reserveBar);
      final gasLowWarnings = result.warnings
          .where((w) => w.type == PlanWarningType.gasLow)
          .toList();

      expect(gasLowWarnings, hasLength(1));
      expect(gasLowWarnings.first.threshold, reserveBar);
      expect(result.gasConsumptions.first.reserveViolation, isTrue);
    });

    test(
      'gasLow warning threshold reflects user-entered reserve, not hardcoded 50 bar',
      () {
        // A user sets reserve to 600 psi (≈ 41.37 bar). The warning's
        // threshold must be ~41.37, NOT 50 (the old hardcoded value).
        final reserveBar = psiToBar(600);
        final result = calculateWithReserve(reserveBar);
        final gasLowWarning = result.warnings.firstWhere(
          (w) => w.type == PlanWarningType.gasLow,
        );

        expect(gasLowWarning.threshold, reserveBar);
        expect(gasLowWarning.threshold, isNot(equals(50)));
      },
    );

    test('no gasLow warning when bar reserve is below remaining', () {
      // With 35 bar remaining, a 30 bar reserve should produce no warning.
      final result = calculateWithReserve(30);
      final gasLowWarnings = result.warnings
          .where((w) => w.type == PlanWarningType.gasLow)
          .toList();

      expect(gasLowWarnings, isEmpty);
      expect(result.gasConsumptions.first.reserveViolation, isFalse);
    });

    test('gasLow warning when bar reserve is above remaining', () {
      // With 35 bar remaining, a 40 bar reserve should trigger a warning.
      final result = calculateWithReserve(40);
      final gasLowWarnings = result.warnings
          .where((w) => w.type == PlanWarningType.gasLow)
          .toList();

      expect(gasLowWarnings, hasLength(1));
      expect(gasLowWarnings.first.threshold, 40);
      expect(result.gasConsumptions.first.reserveViolation, isTrue);
    });
  });

  group('PlanCalculatorService ideal ascent gas', () {
    final calculator = PlanCalculatorService();

    // Deep air dive that incurs deco; the only difference between the two
    // runs is the carried gas set passed to calculatePlan (which feeds the
    // ascent gas plan). The bottom loading is identical.
    const air = DiveTank(
      id: 'back',
      name: 'Back gas',
      volume: 24,
      startPressure: 230,
      gasMix: GasMix(o2: 21),
      role: TankRole.backGas,
    );
    const ean50 = DiveTank(
      id: 'deco',
      name: 'EAN50',
      volume: 11.1,
      startPressure: 200,
      gasMix: GasMix(o2: 50),
      role: TankRole.deco,
    );

    // Descent + bottom only, ending AT depth so calculatePlan builds the full
    // deco schedule from the bottom (createSimplePlan ends at the surface).
    List<PlanSegment> decoSegments() => [
      PlanSegment.descent(
        id: 'descent',
        targetDepth: 45,
        tankId: air.id,
        gasMix: air.gasMix,
        order: 0,
      ),
      PlanSegment.bottom(
        id: 'bottom',
        depth: 45,
        durationMinutes: 25,
        tankId: air.id,
        gasMix: air.gasMix,
        order: 1,
      ),
    ];

    int totalStopSeconds(List<DiveTank> tanks) {
      final result = calculator.calculatePlan(
        segments: decoSegments(),
        tanks: tanks,
        sacRate: 15,
      );
      return result.decoSchedule.fold<int>(
        0,
        (sum, stop) => sum + stop.durationSeconds,
      );
    }

    test('ideal-gas ascent gives <= deco time than fixed back gas', () {
      final fixedTotal = totalStopSeconds([air]);
      final idealTotal = totalStopSeconds([air, ean50]);

      expect(fixedTotal, greaterThan(0));
      expect(idealTotal, lessThanOrEqualTo(fixedTotal));
    });

    test('deco stops report the gas actually breathed at each stop', () {
      final result = calculator.calculatePlan(
        segments: decoSegments(),
        tanks: [air, ean50],
        sacRate: 15,
      );

      // EAN50 (MOD 22 m @1.6) must be selected at the 21/18/.../6 m stops.
      final ean50Stop = result.decoSchedule.firstWhere(
        (s) => s.depth <= 21 && s.depth > 6,
        orElse: () => result.decoSchedule.first,
      );
      expect(ean50Stop.gasMix.o2, closeTo(50, 1e-6));
    });
  });
}
