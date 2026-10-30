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
        // This profile ends with ~25.6 bar (~371 psi) remaining once gas
        // compressibility is accounted for. A user entering 350 psi as
        // reserve (≈ 24.13 bar) should see NO warning, because
        // 25.6 bar remaining > 24.13 bar reserve.
        final result = calculateWithReserve(psiToBar(350));
        final gasLowWarnings = result.warnings
            .where((w) => w.type == PlanWarningType.gasLow)
            .toList();

        expect(gasLowWarnings, isEmpty);
        expect(result.gasConsumptions.first.reserveViolation, isFalse);
      },
    );

    test('gasLow warning when reserve entered as psi is above remaining', () {
      // Same profile (~371 psi remaining). A user entering 600 psi as
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
      // With ~25.6 bar remaining (compressibility-aware), a 20 bar reserve
      // should produce no warning.
      final result = calculateWithReserve(20);
      final gasLowWarnings = result.warnings
          .where((w) => w.type == PlanWarningType.gasLow)
          .toList();

      expect(gasLowWarnings, isEmpty);
      expect(result.gasConsumptions.first.reserveViolation, isFalse);
    });

    test('gasLow warning when bar reserve is above remaining', () {
      // With ~25.6 bar remaining, a 40 bar reserve should trigger a warning.
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
      PlanSegment.travel(
        id: 'descent',
        fromDepth: 0,
        targetDepth: 45,
        tankId: air.id,
        gasMix: air.gasMix,
        order: 0,
        ratePerMinute: 18.0,
      ),
      PlanSegment.hold(
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

    test('a diluent ascent gas follows its own CCR Dil MOD limit', () {
      const dil = DiveTank(
        id: 'dil',
        name: 'EAN40 dil',
        volume: 11.1,
        startPressure: 200,
        gasMix: GasMix(o2: 40),
        role: TankRole.diluent,
      );
      // Deep enough that the deco schedule carries a stop at 30 m and 27 m:
      // within EAN40's 30 m Dil MOD (ppO2 1.6) but above its 25 m bottom
      // limit MOD (ppO2 1.4), so only the fix reaches the diluent there.
      final segments = [
        PlanSegment.travel(
          id: 'descent',
          fromDepth: 0,
          targetDepth: 60,
          tankId: air.id,
          gasMix: air.gasMix,
          order: 0,
          ratePerMinute: 18.0,
        ),
        PlanSegment.hold(
          id: 'bottom',
          depth: 60,
          durationMinutes: 35,
          tankId: air.id,
          gasMix: air.gasMix,
          order: 1,
        ),
      ];

      final withDilMod = PlanCalculatorService(ccrDiluentModPpO2: 1.6);
      final result = withDilMod.calculatePlan(
        segments: segments,
        tanks: [air, dil],
        sacRate: 15,
      );
      final stop30 = result.decoSchedule.firstWhere((s) => s.depth == 30);
      final stop27 = result.decoSchedule.firstWhere((s) => s.depth == 27);
      expect(stop30.gasMix.o2, closeTo(40, 1e-6));
      expect(stop27.gasMix.o2, closeTo(40, 1e-6));

      // At the bottom ppO2 limit instead, those same stops fall back to
      // back gas: the bug this guards against.
      final withoutDilMod = PlanCalculatorService(ccrDiluentModPpO2: 1.4);
      final buggy = withoutDilMod.calculatePlan(
        segments: segments,
        tanks: [air, dil],
        sacRate: 15,
      );
      final buggyStop30 = buggy.decoSchedule.firstWhere((s) => s.depth == 30);
      expect(buggyStop30.gasMix.o2, closeTo(21, 1e-6));
    });

    // Regression for a Copilot review finding (issue #3580 follow-up): a
    // plan's own Custom band override must govern even when the diver's
    // Settings ppO2DecoBandsEnabled toggle is off - "Custom" is a per-plan
    // opt-in, not something the global switch can silently veto.
    test("a plan's custom band override takes effect even when "
        'ppO2DecoBandsEnabled is off', () {
      // EAN50 (50% O2) falls in band3 (45-99%). At the flat 1.6 limit its
      // MOD is 22 m, which lets it cover the 18 m stop (see "deco stops
      // report the gas actually breathed at each stop" below). Lowering
      // band3 to 1.3 bar brings that MOD to 16 m, pushing the 18 m stop
      // back onto back gas - but only if the override actually took
      // effect despite the global toggle staying off.
      final overridden = calculator.calculatePlan(
        segments: decoSegments(),
        tanks: [air, ean50],
        sacRate: 15,
        decoPpO2Band3: 1.3,
      );
      final overriddenStop18 = overridden.decoSchedule.firstWhere(
        (s) => s.depth == 18,
      );
      expect(overriddenStop18.gasMix.o2, closeTo(21, 1e-6));

      // Same plan, no override: the flat 1.6 limit keeps EAN50 eligible
      // at 18 m, same as the dedicated gas-selection test below.
      final plain = calculator.calculatePlan(
        segments: decoSegments(),
        tanks: [air, ean50],
        sacRate: 15,
      );
      final plainStop18 = plain.decoSchedule.firstWhere((s) => s.depth == 18);
      expect(plainStop18.gasMix.o2, closeTo(50, 1e-6));
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

  group('PlanCalculatorService createSimplePlan', () {
    final calculator = PlanCalculatorService();

    const tank = DiveTank(
      id: 'tank-1',
      name: 'AL80',
      volume: 11.1,
      workingPressure: 207,
      startPressure: 200,
      gasMix: GasMix(o2: 21, he: 0),
      order: 0,
    );

    test('shallow plan ascends straight to the surface, no safety stop', () {
      final segments = calculator.createSimplePlan(
        maxDepth: 8,
        bottomTimeMinutes: 30,
        tank: tank,
      );

      // Descent, bottom, one direct ascent - nothing at 5 m.
      expect(segments, hasLength(3));
      expect(segments.map((s) => s.order), [0, 1, 2]);
      expect(segments.map((s) => s.targetDepth), [8.0, 8.0, 0.0]);
      expect(segments.any((s) => s.targetDepth == 5.0), isFalse);

      expect(segments[1].durationSeconds, 30 * 60);
      // 8 m at the default ascent rate, expressed as a duration.
      expect(
        segments.last.durationSeconds,
        closeTo(8 / calculator.defaultAscentRate * 60, 1),
      );
      expect(segments.every((s) => s.tankId == tank.id), isTrue);
    });

    test('plan deeper than 10 m inserts a 3 min safety stop at 5 m', () {
      final segments = calculator.createSimplePlan(
        maxDepth: 18,
        bottomTimeMinutes: 40,
        tank: tank,
      );

      expect(segments, hasLength(5));
      expect(segments.map((s) => s.order), [0, 1, 2, 3, 4]);
      expect(segments.map((s) => s.targetDepth), [18.0, 18.0, 5.0, 5.0, 0.0]);
      expect(segments[3].durationSeconds, 3 * 60);
    });
  });
}
