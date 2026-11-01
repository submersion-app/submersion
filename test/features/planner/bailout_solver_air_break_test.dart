import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/deco_model.dart';
import 'package:submersion/core/deco/entities/breathing_config.dart';
import 'package:submersion/core/deco/entities/deco_status.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';
import 'package:submersion/features/planner/domain/services/bailout_chart_support.dart';
import 'package:submersion/features/planner/domain/services/bailout_solver.dart';
import 'package:submersion/features/planner/domain/services/plan_engine.dart';

const _air = GasMix();
const _stressedAmv = 20.0;

/// A CCR plan deep and long enough that its bailout owes a single oxygen stop
/// at 6 m with air breaks, carried on air and oxygen bailout cylinders.
domain.DivePlan _plan({
  AirBreakPolicy? airBreaks,
  double? hypercapniaAmv,
  int? hypercapniaMinutes,
}) => domain.DivePlan(
  id: 'plan-1',
  name: 'bailout air breaks',
  mode: domain.PlanMode.ccr,
  gfLow: 30,
  gfHigh: 70,
  lastStopDepth: 6,
  sacStressed: _stressedAmv,
  problemSolvingMinutes: 0,
  airBreaks: airBreaks,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
  hypercapniaAmv: hypercapniaAmv,
  hypercapniaMinutes: hypercapniaMinutes,
  hypercapniaExplicitlyOff: hypercapniaMinutes == null,
  tanks: const [
    DiveTank(
      id: 'dil',
      volume: 3,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.diluent,
    ),
    DiveTank(
      id: 'back',
      volume: 40,
      startPressure: 200,
      gasMix: _air,
      role: TankRole.bailout,
    ),
    DiveTank(
      id: 'o2',
      volume: 11,
      startPressure: 200,
      gasMix: GasMix(o2: 100),
      role: TankRole.bailout,
    ),
  ],
  segments: [
    PlanSegment.travel(
      id: 'descent',
      fromDepth: 0,
      targetDepth: 45,
      tankId: 'dil',
      gasMix: _air,
      order: 0,
      ratePerMinute: 18,
    ),
    PlanSegment.hold(
      id: 'bottom',
      depth: 45,
      durationMinutes: 40,
      tankId: 'dil',
      gasMix: _air,
      order: 1,
    ),
  ],
);

double _usedFrom(BailoutOutcome outcome, String tankId) => outcome
    .bailoutTankUsages
    .firstWhere((usage) => usage.tankId == tankId)
    .litersUsed;

class _State extends TissueState {
  const _State();
}

/// Records what each second of a replayed stop is breathed from, in order.
class _BreathingLog extends Fake implements DecoModel {
  final fO2BySecondsBreathed = <(double, int)>[];

  @override
  TissueState applySegment(
    TissueState state,
    DecoSegment segment,
    BreathingConfig breathing,
  ) {
    final fO2 = (breathing as OpenCircuit).fO2;
    final last = fO2BySecondsBreathed.lastOrNull;
    if (last != null && (last.$1 - fO2).abs() < 1e-9) {
      fO2BySecondsBreathed.last = (fO2, last.$2 + segment.durationSeconds);
    } else {
      fO2BySecondsBreathed.add((fO2, segment.durationSeconds));
    }
    return state;
  }

  @override
  double ceilingMeters(TissueState state) => 0;

  @override
  double surfaceCeilingMeters(TissueState state) => 0;
}

void main() {
  const solver = BailoutSolver();
  final environment = PlanEngine.environmentFor(_plan());

  group('a bailout air break (issue #3928)', () {
    test('is charged to the break cylinder, not the oxygen', () {
      final outcome = solver.solve(_plan(airBreaks: const AirBreakPolicy()))!;

      final stop = outcome.worstCase.schedule.stops.last;
      expect(stop.depthMeters, 6);
      expect(stop.airBreakSeconds, greaterThan(0));

      final surfacing = outcome.worstCaseRows.last;
      expect(surfacing.kind, PlanScheduleRowKind.ascent);
      expect(surfacing.tankId, 'o2');

      // Oxygen pays for the stop's oxygen minutes and the leg to the surface.
      final oxygenSeconds = stop.durationSeconds - stop.airBreakSeconds;
      final expectedOxygen =
          oxygenSeconds / 60.0 * _stressedAmv * environment.pressureAtDepth(6) +
          surfacing.durationSeconds /
              60.0 *
              _stressedAmv *
              environment.pressureAtDepth(3);
      expect(_usedFrom(outcome, 'o2'), closeTo(expectedOxygen, 1e-6));
    });

    test('charges each run at the rate in force when it is breathed', () {
      const hypercapniaAmv = 60.0;
      const hypercapnicSolver = BailoutSolver(
        config: PlanEngineConfig(hypercapniaEnabled: true),
      );
      const breaks = AirBreakPolicy();
      final baseline = solver.solve(_plan(airBreaks: breaks))!;
      final toStop =
          baseline.ocStops.last.arrivalRuntimeSeconds -
          baseline.worstCase.runtimeSeconds;

      // The window ends 14 to 15 minutes into the stop, inside its first break,
      // so the first 12 oxygen minutes are at the raised rate and the rest are
      // not. Charging the stop's oxygen in one lump would raise 14 of them.
      final outcome = hypercapnicSolver.solve(
        _plan(
          airBreaks: breaks,
          hypercapniaAmv: hypercapniaAmv,
          hypercapniaMinutes: ((toStop + 14 * 60) / 60).ceil(),
        ),
      )!;
      expect(
        outcome.worstCase.runtimeSeconds,
        baseline.worstCase.runtimeSeconds,
      );

      final stop = outcome.worstCase.schedule.stops.last;
      final oxygenSeconds = stop.durationSeconds - stop.airBreakSeconds;
      expect(oxygenSeconds, greaterThan(720));
      final surfacing = outcome.worstCaseRows.last;
      final expectedOxygen =
          (12 * hypercapniaAmv + (oxygenSeconds - 720) / 60.0 * _stressedAmv) *
              environment.pressureAtDepth(6) +
          surfacing.durationSeconds /
              60.0 *
              _stressedAmv *
              environment.pressureAtDepth(3);
      expect(_usedFrom(outcome, 'o2'), closeTo(expectedOxygen, 1e-6));
    });

    test('is breathed in its own runs on the ceiling trace', () {
      final log = _BreathingLog();
      const point = BailoutPoint(
        runtimeSeconds: 0,
        depthMeters: 6,
        ttsSeconds: 1800,
        litersRequired: 0,
        schedule: DecoSchedule(
          stops: [
            DecoStop(
              depthMeters: 6,
              durationSeconds: 1800,
              airBreakSeconds: 360,
            ),
          ],
          ttsSeconds: 1800,
        ),
      );

      worstCaseCeilingTrace(
        model: log,
        points: [point],
        states: const [_State()],
        worstIndex: 0,
        bailoutPlan: OptimalOcAscentGas(
          gases: const [
            AvailableGas(fN2: 0.79, fHe: 0, maxPpO2Mod: 66),
            AvailableGas(fN2: 0, fHe: 0, maxPpO2Mod: 6),
          ],
          maxPpO2: 1.6,
        ),
        policy: const SchedulePolicy(airBreaks: AirBreakPolicy()),
      );

      // The last run carries on up the leg to the surface, still on oxygen.
      final runs = log.fO2BySecondsBreathed;
      expect(runs, hasLength(3));
      expect(runs[0].$1, closeTo(1, 1e-9));
      expect(runs[0].$2, 720);
      expect(runs[1].$1, closeTo(0.21, 1e-9));
      expect(runs[1].$2, 360);
      expect(runs[2].$1, closeTo(1, 1e-9));
      expect(runs[2].$2, greaterThan(720));
    });

    test('keeps the worst case total the cylinders add up to', () {
      final outcome = solver.solve(_plan(airBreaks: const AirBreakPolicy()))!;

      // Within the whole-second rounding of a leg split at a gas switch.
      expect(
        _usedFrom(outcome, 'back') + _usedFrom(outcome, 'o2'),
        closeTo(outcome.worstCase.litersRequired, 0.1),
      );
    });

    test('shows on the worst case table as the stop line does on a plan', () {
      final outcome = solver.solve(_plan(airBreaks: const AirBreakPolicy()))!;
      final stop = outcome.worstCase.schedule.stops.last;

      final row = outcome.worstCaseRows.lastWhere(
        (row) => row.kind == PlanScheduleRowKind.stop,
      );
      expect(row.airBreakSeconds, stop.airBreakSeconds);
      expect(row.airBreakTankId, 'back');
    });

    test('names the break cylinder on the chart stops too', () {
      final outcome = solver.solve(_plan(airBreaks: const AirBreakPolicy()))!;

      expect(outcome.ocStops.last.airBreakTankId, 'back');
    });

    test('leaves a stop with no break on the stop gas alone', () {
      final outcome = solver.solve(_plan())!;
      final stop = outcome.worstCase.schedule.stops.last;
      expect(stop.airBreakSeconds, 0);

      final surfacing = outcome.worstCaseRows.last;
      expect(
        outcome.worstCaseRows.every((r) => r.airBreakTankId == null),
        isTrue,
      );
      final expectedOxygen =
          stop.durationSeconds /
              60.0 *
              _stressedAmv *
              environment.pressureAtDepth(6) +
          surfacing.durationSeconds /
              60.0 *
              _stressedAmv *
              environment.pressureAtDepth(3);
      expect(_usedFrom(outcome, 'o2'), closeTo(expectedOxygen, 1e-6));
    });
  });
}
