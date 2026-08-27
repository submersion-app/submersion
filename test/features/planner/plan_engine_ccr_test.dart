import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _diluent = GasMix(o2: 18, he: 45);
const _diluentTank = DiveTank(
  id: 'dil',
  volume: 3.0,
  startPressure: 200,
  gasMix: _diluent,
  role: TankRole.diluent,
);
const _o2Tank = DiveTank(
  id: 'o2',
  volume: 3.0,
  startPressure: 200,
  gasMix: GasMix(o2: 100),
  role: TankRole.oxygenSupply,
);
const _bailoutTank = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 207,
  gasMix: GasMix(o2: 50),
  role: TankRole.bailout,
);

List<PlanSegment> _segments({double depth = 60.0, int minutes = 25}) => [
  PlanSegment.descent(
    id: 'seg-1',
    targetDepth: depth,
    tankId: 'dil',
    gasMix: _diluent,
    order: 0,
  ),
  PlanSegment.bottom(
    id: 'seg-2',
    depth: depth,
    durationMinutes: minutes,
    tankId: 'dil',
    gasMix: _diluent,
    order: 1,
  ),
];

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.ccr,
  List<DiveTank> tanks = const [_diluentTank, _o2Tank, _bailoutTank],
}) {
  return domain.DivePlan(
    id: 'plan-1',
    name: 'CCR test',
    mode: mode,
    gfLow: 50,
    gfHigh: 80,
    tanks: tanks,
    segments: _segments(),
    createdAt: DateTime(2026, 7, 5),
    updatedAt: DateTime(2026, 7, 5),
  );
}

void main() {
  const engine = PlanEngine();

  group('PlanEngine CCR', () {
    test('loop deco is shorter than OC deco on the diluent alone', () {
      final ccr = engine.compute(_plan());
      // The honest OC baseline carries ONLY the diluent: giving the OC plan
      // the O2/EAN50 cylinders would hand it deco gases the loop's low
      // shallow setpoint (0.7 bar) cannot match.
      final ocDiluentOnly = engine.compute(
        _plan(mode: domain.PlanMode.oc, tanks: const [_diluentTank]),
      );

      expect(ccr.stops, isNotEmpty);
      expect(
        ccr.totalDecoSeconds,
        lessThan(ocDiluentOnly.totalDecoSeconds),
        reason: 'constant-ppO2 loop off-gasses faster than OC diluent',
      );
    });

    test('O2 consumption is metabolic rate times runtime', () {
      final outcome = engine.compute(_plan());
      final o2 = outcome.tankUsages.firstWhere((u) => u.tankId == 'o2');
      expect(o2.litersUsed, closeTo(1.0 * outcome.runtimeSeconds / 60.0, 1.0));
    });

    test('diluent charged for the descent loop fill; bailout untouched', () {
      final outcome = engine.compute(_plan());
      final diluent = outcome.tankUsages.firstWhere((u) => u.tankId == 'dil');
      // 6 L loop x 6 bar depth-pressure delta at 60 m standard.
      expect(diluent.litersUsed, closeTo(36.0, 0.5));
      final bailout = outcome.tankUsages.firstWhere((u) => u.tankId == 'bo');
      expect(bailout.litersUsed, 0.0);
      expect(bailout.reserveViolation, isFalse);
    });

    test('CCR ppO2 and CNS run on the setpoint, not the diluent', () {
      final outcome = engine.compute(_plan());
      // At 1.3 bar setpoint no ppO2 issue should fire even at 60 m, where
      // OC on the diluent would be far below any limit anyway; the real
      // check: max segment ppO2 equals the high setpoint.
      final bottom = outcome.segmentOutcomes.last;
      expect(bottom.maxPpO2, closeTo(1.3, 1e-9));
      expect(
        outcome.issues.map((i) => i.type),
        isNot(contains(PlanIssueType.ppO2Critical)),
      );
    });

    test(
      'noBailoutCarried fires without a bailout tank and clears with one',
      () {
        final without = engine.compute(
          _plan(tanks: const [_diluentTank, _o2Tank]),
        );
        expect(
          without.issues.map((i) => i.type),
          contains(PlanIssueType.noBailoutCarried),
        );
        // OC-specific "no deco gas" alert must NOT fire for CCR.
        expect(
          without.issues.map((i) => i.type),
          isNot(contains(PlanIssueType.ndlExceededNoDecoGas)),
        );

        final withBailout = engine.compute(_plan());
        expect(
          withBailout.issues.map((i) => i.type),
          isNot(contains(PlanIssueType.noBailoutCarried)),
        );
      },
    );
  });
}
