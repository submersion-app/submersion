import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_plan_handoff.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_result.dart';

import '../support/synthetic_dives.dart';

ScenarioRequest _request(
  SyntheticDive dive, {
  required int branchSeconds,
  ScenarioMode mode = ScenarioMode.replan,
  List<ScenarioIntervention> interventions = const [],
  DiveMode diveMode = DiveMode.oc,
  ScenarioSettings settings = const ScenarioSettings(),
}) => ScenarioRequest(
  diveId: 'd',
  depths: dive.depths,
  timestamps: dive.timestamps,
  diveMode: diveMode,
  tanks: dive.tanks,
  gasSwitches: dive.switches,
  tankPressures: dive.tankPressures,
  settings: settings,
  scenario: DiveScenario(
    id: 's',
    diveId: 'd',
    name: 'n',
    branchSeconds: branchSeconds,
    mode: mode,
    interventions: interventions,
    createdAt: DateTime(2026, 9, 25),
    updatedAt: DateTime(2026, 9, 25),
  ),
);

Dive _dive(SyntheticDive d) => Dive(
  id: 'd',
  dateTime: DateTime(2026, 9, 25, 9),
  diveMode: DiveMode.oc,
  tanks: d.tanks,
  profile: [
    for (var i = 0; i < d.depths.length; i++)
      DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
  ],
);

List<GasSwitch> _switches(SyntheticDive d) => [
  for (final (i, s) in d.switches.indexed)
    GasSwitch(
      id: 'gs$i',
      diveId: 'd',
      timestamp: s.timestamp,
      tankId: s.tankId,
      createdAt: DateTime(2026, 9, 25, 9),
    ),
];

DivePlanState _defaults() {
  final now = DateTime(2026, 9, 25);
  return DivePlanState(
    id: 'template',
    name: 'template',
    segments: const [],
    tanks: const [],
    sacFactor: 3.0,
    problemSolvingMinutes: 4,
    createdAt: now,
    updatedAt: now,
  );
}

ScenarioPlanHandoffResult _handoff(
  SyntheticDive d,
  ScenarioRequest request, {
  DiveScenario? scenario,
}) {
  final outcome = const ScenarioEngine().run(request);
  return buildScenarioPlanHandoff(
    request: request,
    outcome: outcome,
    scenario: scenario ?? request.scenario,
    dive: _dive(d),
    profile: _dive(d).profile,
    gasSwitches: _switches(d),
    defaults: _defaults(),
    planName: 'What if: test',
  );
}

void main() {
  final d = squareDive(depth: 40, bottomMinutes: 25);

  test('segments are continuous at the branch and the remainder follows', () {
    final request = _request(d, branchSeconds: 900);
    final outcome = const ScenarioEngine().run(request);
    final result = _handoff(d, request);
    final remainder = outcome.compiledPlan!.segments.length;
    final authored = result.plan.segments.length - remainder;
    expect(authored, greaterThanOrEqualTo(2));
    final authoredSeconds = result.plan.segments
        .take(authored)
        .fold<int>(0, (a, s) => a + s.durationSeconds);
    expect(authoredSeconds, 900);
    for (var i = 0; i < result.plan.segments.length; i++) {
      expect(result.plan.segments[i].order, i);
    }
    expect(result.plan.sourceDiveId, 'd');
    expect(result.plan.name, 'What if: test');
    expect(result.notes, isEmpty);
  });

  test('a tank lost after the branch is absent from the plan', () {
    final request = _request(
      d,
      branchSeconds: 900,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
    );
    final result = _handoff(d, request);
    expect(result.plan.tanks.any((t) => t.id == 'deco50'), isFalse);
    expect(result.notes, isEmpty);
  });

  test('a tank already breathed before the branch stays, with a note', () {
    final afterSwitch = d.timestamps[d.switchIndex] + 60;
    final request = _request(
      d,
      branchSeconds: afterSwitch,
      interventions: const [LoseTankIntervention(tankId: 'deco50')],
    );
    final result = _handoff(d, request);
    expect(result.plan.segments.any((s) => s.tankId == 'deco50'), isTrue);
    expect(result.plan.tanks.any((t) => t.id == 'deco50'), isTrue);
    expect(result.notes, contains(ScenarioHandoffNote.lostTankKept));
  });

  test(
    'original start pressures are restored and a hypothetical tank is added',
    () {
      final request = _request(
        d,
        branchSeconds: 900,
        interventions: const [
          SwitchGasIntervention(
            tank: HypotheticalTankRef(
              gasMix: GasMix(o2: 32, he: 0),
              volumeLiters: 11,
              startPressureBar: 200,
            ),
          ),
        ],
      );
      final result = _handoff(d, request);
      final back = result.plan.tanks.firstWhere((t) => t.id == 'back');
      final original = request.tanks.firstWhere((t) => t.id == 'back');
      expect(back.startPressure, original.startPressure);
      expect(result.plan.tanks.any((t) => t.gasMix.o2 == 32), isTrue);
    },
  );

  test('gradient factors come from the intervention', () {
    final request = _request(
      d,
      branchSeconds: 900,
      interventions: const [ChangeGfIntervention(gfLow: 40, gfHigh: 85)],
    );
    final result = _handoff(d, request);
    expect(result.plan.gfLow, 40);
    expect(result.plan.gfHigh, 85);
  });

  test('share-gas hands off the stressed SAC', () {
    final plain = _handoff(d, _request(d, branchSeconds: 900));
    final shared = _handoff(
      d,
      _request(
        d,
        branchSeconds: 900,
        interventions: const [ShareGasIntervention()],
      ),
    );
    expect(shared.plan.sacRate, greaterThan(plain.plan.sacRate));
    expect(
      shared.plan.sacRate,
      closeTo(
        plain.plan.sacRate * 2.5 * const ScenarioSettings().buddyFactor,
        1e-6,
      ),
    );
  });

  test('settings and defaults map field for field', () {
    final request = _request(d, branchSeconds: 900);
    final result = _handoff(d, request);
    expect(result.plan.ppO2Bottom, request.settings.ppO2Working);
    expect(result.plan.ppO2Deco, request.settings.ppO2Deco);
    expect(result.plan.sacFactor, 3.0);
    expect(result.plan.problemSolvingMinutes, 4);
    expect(result.plan.stopMinimums, isEmpty);
    expect(result.plan.surfaceInterval, isNull);
    expect(result.plan.isDirty, isFalse);
  });

  test('the residual tissue seed rides along', () {
    final seed = const ScenarioEngine()
        .run(_request(d, branchSeconds: 900))
        .actual
        .decoStatuses
        .last
        .compartments;
    final base = _request(d, branchSeconds: 900);
    final request = ScenarioRequest(
      diveId: base.diveId,
      depths: base.depths,
      timestamps: base.timestamps,
      diveMode: base.diveMode,
      tanks: base.tanks,
      gasSwitches: base.gasSwitches,
      tankPressures: base.tankPressures,
      startCompartments: seed,
      startCns: 0,
      startOtu: 0,
      settings: base.settings,
      scenario: base.scenario,
    );
    final result = _handoff(d, request);
    expect(result.plan.initialTissueState, seed);
  });

  test('notes name what was not carried', () {
    final replay = _request(d, branchSeconds: 900, mode: ScenarioMode.replan);
    final replayDraft = replay.scenario.copyWith(mode: ScenarioMode.replay);
    expect(_handoff(d, replay, scenario: replayDraft).notes, [
      ScenarioHandoffNote.replayReplanned,
    ]);
    final policy = _request(
      d,
      branchSeconds: 900,
      interventions: const [
        AscentPolicyIntervention(extraLastStopSeconds: 120),
      ],
    );
    expect(_handoff(d, policy).notes, [
      ScenarioHandoffNote.extraLastStopNotCarried,
    ]);
  });

  test('a branch at the first sample yields the remainder alone', () {
    final request = _request(d, branchSeconds: 0);
    final outcome = const ScenarioEngine().run(request);
    final result = _handoff(d, request);
    expect(result.plan.segments.length, outcome.compiledPlan!.segments.length);
  });

  test('a branch at the last sample does not throw', () {
    final request = _request(d, branchSeconds: d.timestamps.last);
    expect(() => _handoff(d, request), returnsNormally);
  });

  test('a rebreather request is refused', () {
    final request = _request(d, branchSeconds: 900, diveMode: DiveMode.ccr);
    final outcome = const ScenarioEngine().run(_request(d, branchSeconds: 900));
    expect(
      () => buildScenarioPlanHandoff(
        request: request,
        outcome: outcome,
        scenario: request.scenario,
        dive: _dive(d),
        profile: _dive(d).profile,
        gasSwitches: _switches(d),
        defaults: _defaults(),
        planName: 'x',
      ),
      throwsArgumentError,
    );
  });

  test('a replay outcome without a compiled plan is refused', () {
    final request = _request(d, branchSeconds: 900, mode: ScenarioMode.replay);
    final outcome = const ScenarioEngine().run(request);
    expect(outcome.compiledPlan, isNull);
    expect(
      () => buildScenarioPlanHandoff(
        request: request,
        outcome: outcome,
        scenario: request.scenario,
        dive: _dive(d),
        profile: _dive(d).profile,
        gasSwitches: _switches(d),
        defaults: _defaults(),
        planName: 'x',
      ),
      throwsArgumentError,
    );
  });
}
