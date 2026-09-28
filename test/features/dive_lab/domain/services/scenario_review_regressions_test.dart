import '../support/synthetic_dives.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

ScenarioRequest request(
  SyntheticDive d,
  int branch,
  ScenarioMode mode,
  List<ScenarioIntervention> interventions, {
  List<ScenarioGasSwitch>? switches,
  DiveMode diveMode = DiveMode.oc,
}) => ScenarioRequest(
  diveId: 'd',
  depths: d.depths,
  timestamps: d.timestamps,
  tanks: d.tanks,
  gasSwitches: switches ?? d.switches,
  tankPressures: d.tankPressures,
  diveMode: diveMode,
  scrInjectionRate: 10,
  scrSupplyO2Percent: 50,
  scenario: DiveScenario(
    id: 's',
    diveId: 'd',
    name: 's',
    branchSeconds: branch,
    mode: mode,
    interventions: interventions,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  ),
);
void main() {
  const engine = ScenarioEngine();
  test('replay preserves gas breathed before losing a cylinder', () {
    final d = squareDive(depth: 30, bottomMinutes: 10);
    final o = engine.run(
      request(
        d,
        600,
        ScenarioMode.replay,
        const [LoseTankIntervention(tankId: 'deco50')],
        switches: const [ScenarioGasSwitch(timestamp: 120, tankId: 'deco50')],
      ),
    );
    final i = d.indexAt(300);
    expect(o.counterfactual.ppO2Curve[i], o.actual.ppO2Curve[i]);
  });
  test('replan does not breathe a lost cylinder in remaining bottom', () {
    final d = squareDive(depth: 30, bottomMinutes: 10);
    final o = engine.run(
      request(
        d,
        300,
        ScenarioMode.replan,
        const [LoseTankIntervention(tankId: 'deco50')],
        switches: const [ScenarioGasSwitch(timestamp: 120, tankId: 'deco50')],
      ),
    );
    expect(
      o.compiledPlan!.segments
          .where((s) => s.durationSeconds > 0)
          .any((s) => s.tankId == 'deco50'),
      isFalse,
    );
  });
  test('later ascent works at the default final ascent branch', () {
    final d = squareDive(depth: 30, bottomMinutes: 10);
    final t = d.timestamps[d.bottomEndIndex];
    final base = engine.run(request(d, t, ScenarioMode.replan, []));
    final shifted = engine.run(
      request(d, t, ScenarioMode.replan, const [
        ShiftAscentIntervention(deltaSeconds: 300),
      ]),
    );
    expect(
      shifted.compiledPlan!.segments.fold<int>(
        0,
        (n, s) => n + s.durationSeconds,
      ),
      300,
    );
    expect(
      shifted.counterfactualTimestamps.last,
      greaterThan(base.counterfactualTimestamps.last),
    );
  });
  test('replan preserves a recorded gas switch during a flat bottom', () {
    final d = squareDive(depth: 30, bottomMinutes: 10);
    final o = engine.run(
      request(
        d,
        300,
        ScenarioMode.replan,
        [],
        switches: const [ScenarioGasSwitch(timestamp: 450, tankId: 'deco50')],
      ),
    );
    final timed = o.compiledPlan!.segments
        .where((s) => s.durationSeconds > 0)
        .toList();
    expect(timed.map((s) => (s.tankId, s.durationSeconds)), [
      ('back', 150),
      ('deco50', 240),
    ]);
  });
  test('SCR remainder does not integrate tissues using CCR setpoints', () {
    final d = squareDive(depth: 30, bottomMinutes: 10, withDeco50: false);
    final o = engine.run(
      request(d, 300, ScenarioMode.replan, [], diveMode: DiveMode.scr),
    );
    final g = o.counterfactualGasSegments.firstWhere(
      (g) => g.startTimestamp >= 300,
    );

    expect(g.setpoint, isNull);
    final loopO2 = ScrCalculator.calculateCmfSteadyStateFo2(
      injectionRateLpm: 10,
      supplyO2Percent: 50,
    )!;
    expect(g.fN2, closeTo(1 - loopO2, 1e-10));
    expect(o.compiledPlan!.segments.last.gasMix.o2, 50);
  });
  test('runtime table includes extra last-stop seconds', () {
    final d = squareDive(depth: 45, bottomMinutes: 30);
    final o = engine.run(
      request(d, 1500, ScenarioMode.replan, const [
        AscendNowIntervention(),
        AscentPolicyIntervention(extraLastStopSeconds: 120),
      ]),
    );
    expect(
      o.branch.runtimeSeconds + o.planOutcome!.runtimeSeconds,
      o.counterfactualTimestamps.last,
    );
  });

  test('CCR remainder uses the actual diluent rather than first cylinder', () {
    final d = squareDive(depth: 30, bottomMinutes: 10, withDeco50: false);
    final base = request(
      d,
      300,
      ScenarioMode.replan,
      [],
      diveMode: DiveMode.ccr,
    );
    final o = engine.run(
      ScenarioRequest(
        diveId: 'd',
        depths: d.depths,
        timestamps: d.timestamps,
        tanks: const [
          DiveTank(
            id: 'oxygen',
            gasMix: GasMix(o2: 100),
            role: TankRole.oxygenSupply,
          ),
          DiveTank(
            id: 'diluent',
            gasMix: GasMix(o2: 21, he: 35),
            role: TankRole.diluent,
          ),
        ],
        diveMode: DiveMode.ccr,
        setpointHigh: 1.3,
        loopGasSegments: const [
          ProfileGasSegment(
            startTimestamp: 0,
            fN2: 0.44,
            fHe: 0.35,
            setpoint: 1.3,
          ),
        ],
        scenario: base.scenario,
      ),
    );
    expect(o.compiledPlan!.segments.last.gasMix.o2, closeTo(21, 1e-10));
    expect(o.compiledPlan!.segments.last.gasMix.he, 35);
  });
  for (final reverse in [false, true]) {
    test('bailout excludes lost tanks in either order (reverse=$reverse)', () {
      final d = squareDive(depth: 30, bottomMinutes: 10, withDeco50: false);
      final base = request(d, 300, ScenarioMode.replan, const [
        LoseTankIntervention(tankId: 'bo50'),
        BailOutIntervention(),
      ], diveMode: DiveMode.ccr);
      final o = engine.run(
        ScenarioRequest(
          diveId: 'd',
          depths: d.depths,
          timestamps: d.timestamps,
          tanks: const [
            DiveTank(id: 'diluent', gasMix: GasMix(), role: TankRole.diluent),
            DiveTank(id: 'boAir', gasMix: GasMix(), role: TankRole.bailout),
            DiveTank(
              id: 'bo50',
              gasMix: GasMix(o2: 50),
              role: TankRole.bailout,
            ),
          ],
          diveMode: DiveMode.ccr,
          setpointHigh: 1.3,
          loopGasSegments: const [
            ProfileGasSegment(startTimestamp: 0, fN2: 0.7902, setpoint: 1.3),
          ],
          scenario: reverse
              ? base.scenario.copyWith(
                  interventions: base.scenario.interventions.reversed.toList(),
                )
              : base.scenario,
        ),
      );
      expect(
        o.compiledPlan!.segments.every((s) => s.tankId == 'boAir'),
        isTrue,
      );
      expect(o.compiledPlan!.tanks.any((t) => t.id == 'bo50'), isFalse);
    });
  }
}
