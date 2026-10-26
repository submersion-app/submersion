import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/data/services/plan_calculator_service.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';

/// The other two places the planner picks ascent gases follow each
/// cylinder's MOD too (issue #3567): the CCR bailout solver and the
/// planner screen's own result calculator.
const _tx = GasMix(o2: 18, he: 45);
const _ean50 = GasMix(o2: 50);
const _ean40 = GasMix(o2: 40);

List<PlanSegment> _segments(String tankId) => [
  PlanSegment.travel(
    id: 's1',
    fromDepth: 0,
    targetDepth: 60,
    tankId: tankId,
    gasMix: _tx,
    order: 0,
    ratePerMinute: 18,
  ),
  PlanSegment.hold(
    id: 's2',
    depth: 60,
    durationMinutes: 25,
    tankId: tankId,
    gasMix: _tx,
    order: 1,
  ),
];

void main() {
  group('bailout solver', () {
    domain.DivePlan ccr({double? ean50Mod}) => domain.DivePlan(
      id: 'ccr',
      name: 'CCR bailout MOD',
      mode: domain.PlanMode.ccr,
      gfLow: 30,
      gfHigh: 70,
      tanks: [
        const DiveTank(
          id: 'dil',
          volume: 3,
          startPressure: 200,
          gasMix: _tx,
          role: TankRole.diluent,
        ),
        const DiveTank(
          id: 'bo-tx',
          volume: 11.1,
          startPressure: 207,
          gasMix: _tx,
          role: TankRole.bailout,
        ),
        DiveTank(
          id: 'bo-50',
          volume: 11.1,
          startPressure: 207,
          gasMix: _ean50,
          role: TankRole.bailout,
          decoSwitchDepth: ean50Mod,
        ),
      ],
      segments: _segments('dil'),
      createdAt: DateTime(2026, 10, 22),
      updatedAt: DateTime(2026, 10, 22),
    );

    double deepestOn(BailoutOutcome outcome, String tankId) => outcome
        .worstCaseRows
        .where((r) => r.tankId == tankId && r.kind == PlanScheduleRowKind.stop)
        .map((r) => r.depthMeters)
        .reduce((a, b) => a > b ? a : b);

    const solver = BailoutSolver();

    test('an EAN50 bailout, richer than air, joins at its deco-limit MOD', () {
      // 1.6 / 0.5 = 3.2 bar: 22 m, so the deepest stop on it is 21 m.
      expect(deepestOn(solver.solve(ccr())!, 'bo-50'), 21);
    });

    test('an override moves where the bailout joins', () {
      expect(deepestOn(solver.solve(ccr(ean50Mod: 15))!, 'bo-50'), 15);
    });
  });

  group('planner screen calculator', () {
    final calculator = PlanCalculatorService(gfLow: 30, gfHigh: 70);

    const back = DiveTank(
      id: 'back',
      volume: 24,
      startPressure: 232,
      gasMix: _tx,
    );
    DiveTank ean40({double? mod}) => DiveTank(
      id: 'ean40',
      volume: 11.1,
      startPressure: 207,
      gasMix: _ean40,
      decoSwitchDepth: mod,
    );

    // This calculator's stops name their gas, not always their tank.
    double deepestOn(PlanResult result, GasMix gas) => result.decoSchedule
        .where((s) => s.gasMix == gas)
        .map((s) => s.depth)
        .reduce((a, b) => a > b ? a : b);

    PlanResult compute({
      double? mod,
      Map<String, TankRole> roles = const {
        'back': TankRole.backGas,
        'ean40': TankRole.deco,
      },
    }) => calculator.calculatePlan(
      segments: _segments('back'),
      tanks: [
        back,
        ean40(mod: mod),
      ],
      sacRate: 15,
      tankRoles: roles,
    );

    test('a deco gas joins at its default MOD (30 m at 1.6)', () {
      expect(deepestOn(compute(), _ean40), 30);
    });

    test('an override moves the switch', () {
      expect(deepestOn(compute(mod: 21), _ean40), 21);
    });

    test('a stage role uses the bottom limit (25 m at 1.4)', () {
      expect(
        deepestOn(
          compute(
            roles: const {'back': TankRole.backGas, 'ean40': TankRole.stage},
          ),
          _ean40,
        ),
        24,
      );
    });
  });
}
