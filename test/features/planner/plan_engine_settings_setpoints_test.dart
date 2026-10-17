import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

// A plan whose setpoints are unset (saved before the planner seeded them,
// imported from a file without them, or reaching the loop only through a
// per-segment override) must breathe the diver's CCR setpoints from
// Settings, carried in PlanEngineConfig, not the spec 0.7 / 1.3 (#2801).

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

/// The diver's Settings: deliberately off the spec 0.7 / 1.3.
const _settingsConfig = PlanEngineConfig(
  ccrSetpointLow: 0.6,
  ccrSetpointHigh: 1.2,
);

List<PlanSegment> _segments({domain.PlanMode? holdMode}) => [
  PlanSegment.travel(
    id: 'seg-1',
    fromDepth: 0,
    targetDepth: 60,
    tankId: 'dil',
    gasMix: _diluent,
    order: 0,
    ratePerMinute: 18.0,
  ),
  PlanSegment.hold(
    id: 'seg-2',
    depth: 60,
    durationMinutes: 25,
    tankId: 'dil',
    gasMix: _diluent,
    order: 1,
  ).copyWith(diveModeOverride: holdMode),
];

domain.DivePlan _plan({
  domain.PlanMode mode = domain.PlanMode.ccr,
  domain.PlanMode? holdMode,
  double? setpointLow,
  double? setpointHigh,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'Settings setpoints',
  mode: mode,
  gfLow: 50,
  gfHigh: 80,
  setpointLow: setpointLow,
  setpointHigh: setpointHigh,
  tanks: const [_diluentTank, _o2Tank, _bailoutTank],
  segments: _segments(holdMode: holdMode),
  createdAt: DateTime(2026, 10, 17),
  updatedAt: DateTime(2026, 10, 17),
);

PlanScheduleRow _bottomRow(List<PlanScheduleRow> rows) =>
    rows.firstWhere((r) => r.kind == PlanScheduleRowKind.level);

void main() {
  group('setpointAt', () {
    test('falls back to the config setpoints for an unset plan setpoint', () {
      final plan = _plan();
      expect(setpointAt(plan, 30, config: _settingsConfig), 1.2);
      expect(setpointAt(plan, 5, config: _settingsConfig), 0.6);
    });

    test('a plan setpoint wins over the config', () {
      final plan = _plan(setpointLow: 0.8, setpointHigh: 1.4);
      expect(setpointAt(plan, 30, config: _settingsConfig), 1.4);
      expect(setpointAt(plan, 5, config: _settingsConfig), 0.8);
    });

    test('the default config keeps the spec setpoints as the last resort', () {
      final plan = _plan();
      expect(
        setpointAt(plan, 30, config: const PlanEngineConfig()),
        domain.DivePlan.specSetpointHigh,
      );
      expect(
        setpointAt(plan, 5, config: const PlanEngineConfig()),
        domain.DivePlan.specSetpointLow,
      );
    });
  });

  group('PlanEngine', () {
    test('a CCR plan with unset setpoints breathes the Settings high '
        'setpoint on the bottom', () {
      final outcome = const PlanEngine(
        config: _settingsConfig,
      ).compute(_plan());
      expect(_bottomRow(outcome.schedule).ppO2, closeTo(1.2, 0.005));
    });

    test('the computed ascent uses the Settings setpoints, low in the '
        'shallows', () {
      final outcome = const PlanEngine(
        config: _settingsConfig,
      ).compute(_plan());
      final shallowStops = outcome.schedule.where(
        (r) => r.kind == PlanScheduleRowKind.stop && r.depthMeters <= 10,
      );
      final deepStops = outcome.schedule.where(
        (r) => r.kind == PlanScheduleRowKind.stop && r.depthMeters > 10,
      );
      expect(shallowStops, isNotEmpty, reason: 'precondition: shallow deco');
      expect(deepStops, isNotEmpty, reason: 'precondition: deep deco');
      for (final row in shallowStops) {
        expect(row.ppO2, closeTo(0.6, 0.005), reason: '${row.depthMeters} m');
      }
      for (final row in deepStops) {
        expect(row.ppO2, closeTo(1.2, 0.005), reason: '${row.depthMeters} m');
      }
    });

    test('a plan setpoint still wins over the Settings', () {
      final outcome = const PlanEngine(
        config: _settingsConfig,
      ).compute(_plan(setpointHigh: 1.4));
      expect(_bottomRow(outcome.schedule).ppO2, closeTo(1.4, 0.005));
    });

    test('a CCR segment override on an OC plan breathes the Settings '
        'setpoint', () {
      final outcome = const PlanEngine(
        config: _settingsConfig,
      ).compute(_plan(mode: domain.PlanMode.oc, holdMode: domain.PlanMode.ccr));
      expect(_bottomRow(outcome.schedule).ppO2, closeTo(1.2, 0.005));
    });

    test('the Settings setpoints change the computed plan', () {
      final spec = const PlanEngine().compute(_plan());
      final settings = const PlanEngine(
        config: _settingsConfig,
      ).compute(_plan());
      expect(settings.cnsEnd, lessThan(spec.cnsEnd));
    });
  });

  group('BailoutSolver', () {
    test('the loop legs before bailout breathe the Settings setpoint', () {
      final outcome = const BailoutSolver(
        config: _settingsConfig,
      ).solve(_plan())!;
      expect(_bottomRow(outcome.ccrRows).ppO2, closeTo(1.2, 0.005));
    });
  });
}
