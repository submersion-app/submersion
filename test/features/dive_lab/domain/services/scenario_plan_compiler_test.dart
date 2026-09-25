import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_compiler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart'
    as domain;

const back = DiveTank(
  id: 'back',
  volume: 24,
  startPressure: 200,
  gasMix: GasMix(o2: 21),
  role: TankRole.backGas,
);
const deco50 = DiveTank(
  id: 'deco50',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 50),
  role: TankRole.deco,
);
const bo = DiveTank(
  id: 'bo',
  volume: 11.1,
  startPressure: 200,
  gasMix: GasMix(o2: 32),
  role: TankRole.bailout,
);

final scenario = DiveScenario(
  id: 'sc',
  diveId: 'd',
  name: 'What if',
  branchSeconds: 900,
  mode: ScenarioMode.replan,
  createdAt: DateTime(2026, 8, 21),
  updatedAt: DateTime(2026, 8, 21),
);

ScenarioRequest _request({
  List<DiveTank> tanks = const [back, deco50],
  DiveMode mode = DiveMode.oc,
}) => ScenarioRequest(
  diveId: 'd',
  depths: const [0, 40, 40],
  timestamps: const [0, 10, 20],
  diveMode: mode,
  tanks: tanks,
  scenario: scenario,
);

const branch = BranchState(
  index: 1,
  runtimeSeconds: 900,
  depthMeters: 40,
  compartments: [],
  gfLowCeilingAnchor: 12,
  cnsPercent: 5,
  otu: 20,
  activeTankId: 'back',
  tankPressures: [
    TankPressureAtBranch(
      tankId: 'back',
      pressureBar: 130,
      source: PressureSource.measured,
    ),
    TankPressureAtBranch(
      tankId: 'deco50',
      pressureBar: 198,
      source: PressureSource.estimated,
    ),
  ],
  sacLitersPerMin: 18,
  sacSource: SacSource.measured,
);

final bottom = [
  PlanSegment.bottom(
    id: 'lab-seg-0',
    depth: 40,
    durationMinutes: 5,
    tankId: 'back',
    gasMix: const GasMix(o2: 21),
  ),
];

void main() {
  test('baseline: tanks at branch pressure, settings, SAC, identity', () {
    final c = compileScenarioPlan(
      request: _request(),
      branch: branch,
      settings: const ScenarioSettings(gfLow: 0.4, gfHigh: 0.85),
      interventions: const [],
      remainingBottom: bottom,
    );
    final p = c.plan;
    expect(p.id, 'lab-sc');
    expect(p.sourceDiveId, 'd');
    expect(p.mode, domain.PlanMode.oc);
    expect(p.gfLow, 40);
    expect(p.gfHigh, 85);
    expect(p.sacBottom, 18);
    expect(p.sacDeco, isNull);
    expect(p.tanks.map((t) => t.id), ['back', 'deco50']);
    expect(p.tanks[0].startPressure, 130);
    expect(p.tanks[1].startPressure, 198);
    expect(p.segments, bottom);
    expect(p.reservePressure, 50);
    expect(c.forcedTankId, isNull);
  });

  test('loseTank removes the tank', () {
    final c = compileScenarioPlan(
      request: _request(),
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
      remainingBottom: bottom,
    );
    expect(c.plan.tanks.map((t) => t.id), ['back']);
  });

  test('switchGas pins the switch depth and reports the forced tank', () {
    final c = compileScenarioPlan(
      request: _request(),
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [
        SwitchGasIntervention(tank: ExistingTankRef('deco50')),
      ],
      remainingBottom: bottom,
    );
    expect(c.forcedTankId, 'deco50');
    expect(
      c.plan.tanks.firstWhere((t) => t.id == 'deco50').decoSwitchDepth,
      40,
    );
  });

  test('switchGas to a hypothetical tank appends it', () {
    const ref = HypotheticalTankRef(
      gasMix: GasMix(o2: 50),
      volumeLiters: 11.1,
      startPressureBar: 200,
    );
    final c = compileScenarioPlan(
      request: _request(tanks: const [back]),
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [SwitchGasIntervention(tank: ref)],
      remainingBottom: bottom,
    );
    expect(c.plan.tanks.map((t) => t.id), ['back', ref.tankId]);
    expect(c.forcedTankId, ref.tankId);
    expect(c.plan.tanks.last.decoSwitchDepth, 40);
  });

  test('shareGas stresses both SAC rates by the buddy factor', () {
    final c = compileScenarioPlan(
      request: _request(),
      branch: branch,
      settings: const ScenarioSettings(buddyFactor: 2),
      interventions: const [ShareGasIntervention()],
      remainingBottom: bottom,
    );
    expect(c.plan.sacBottom, closeTo(18 * 2.5 * 2, 1e-9));
    expect(c.plan.sacDeco, closeTo(18 * 2.5 * 2, 1e-9));
    final custom = compileScenarioPlan(
      request: _request(),
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [ShareGasIntervention(buddyFactor: 1.5)],
      remainingBottom: bottom,
    );
    expect(custom.plan.sacBottom, closeTo(18 * 2.5 * 1.5, 1e-9));
  });

  test('bailOut compiles an OC plan on the bailout pool at stressed SAC', () {
    final c = compileScenarioPlan(
      request: _request(tanks: const [back, bo], mode: DiveMode.ccr),
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [BailOutIntervention()],
      remainingBottom: bottom,
    );
    expect(c.plan.mode, domain.PlanMode.oc);
    expect(c.plan.tanks.map((t) => t.id), ['bo']);
    expect(c.forcedTankId, 'bo');
    expect(c.plan.sacBottom, closeTo(45, 1e-9));
  });

  test('ascentPolicy overrides the schedule fields', () {
    final c = compileScenarioPlan(
      request: _request(),
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [
        AscentPolicyIntervention(
          ascentRate: 6,
          lastStopDepth: 6,
          gasSwitchStopSeconds: 60,
          extraLastStopSeconds: 120,
        ),
      ],
      remainingBottom: bottom,
    );
    expect(c.plan.ascentRate, 6);
    expect(c.plan.lastStopDepth, 6);
    expect(c.plan.gasSwitchStopSeconds, 60);
    expect(c.extraLastStopSeconds, 120);
  });

  test('ccr request compiles a ccr plan with the setpoints', () {
    final r = ScenarioRequest(
      diveId: 'd',
      depths: const [0, 40, 40],
      timestamps: const [0, 10, 20],
      diveMode: DiveMode.ccr,
      tanks: const [back],
      setpointHigh: 1.3,
      setpointLow: 0.7,
      scenario: scenario,
    );
    final c = compileScenarioPlan(
      request: r,
      branch: branch,
      settings: const ScenarioSettings(),
      interventions: const [],
      remainingBottom: bottom,
    );
    expect(c.plan.mode, domain.PlanMode.ccr);
    expect(c.plan.setpointHigh, 1.3);
    expect(c.plan.setpointLow, 0.7);
  });
}
