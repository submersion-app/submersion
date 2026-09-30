import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/branch_state.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';

import '../support/synthetic_dives.dart';

ScenarioRequest _request(
  SyntheticDive dive, {
  required int branchSeconds,
  ScenarioMode mode = ScenarioMode.replay,
  List<ScenarioIntervention> interventions = const [],
  ScenarioSettings settings = const ScenarioSettings(),
}) => ScenarioRequest(
  diveId: 'd',
  depths: dive.depths,
  timestamps: dive.timestamps,
  diveMode: DiveMode.oc,
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
    createdAt: DateTime(2026, 8, 21),
    updatedAt: DateTime(2026, 8, 21),
  ),
);

ScenarioOutcome _run(ScenarioRequest r) => const ScenarioEngine().run(r);

void main() {
  final dive = squareDive(depth: 45, bottomMinutes: 30); // deco at 30/70
  const branchT = 900; // mid-bottom
  final bottomEndT = dive.timestamps[dive.bottomEndIndex];

  group('replay', () {
    test('identity: no interventions reproduces the actual analysis', () {
      final o = _run(_request(dive, branchSeconds: branchT));
      expect(o.mode, ScenarioMode.replay);
      expect(o.counterfactual.ceilingCurve, o.actual.ceilingCurve);
      expect(o.counterfactual.gfCurve, o.actual.gfCurve);
      expect(o.counterfactual.cnsCurve, o.actual.cnsCurve);
      expect(o.counterfactual.ttsCurve, o.actual.ttsCurve);
      expect(o.counterfactualTimestamps, dive.timestamps);
      expect(
        o.deltas
            .where((d) => d.delta != null)
            .every((d) => d.delta!.abs() < 1e-9),
        isTrue,
      );
    });

    test('changeGf: tissues identical, ceilings differ in deco', () {
      final o = _run(
        _request(
          dive,
          branchSeconds: branchT,
          interventions: const [ChangeGfIntervention(gfLow: 20, gfHigh: 60)],
        ),
      );
      expect(o.counterfactual.gfCurve, o.actual.gfCurve);
      expect(o.counterfactual.surfaceGfCurve, o.actual.surfaceGfCurve);
      expect(o.counterfactual.ceilingCurve, isNot(o.actual.ceilingCurve));
      // Lower GF: deeper ceilings, so more violations on the same path.
      final v = o.deltas.firstWhere(
        (d) => d.metric == DeltaMetric.ceilingViolations,
      );
      expect(v.counterfactual!, greaterThanOrEqualTo(v.actual!));
    });

    test('switchGas at the branch changes CNS after T, nothing before', () {
      final o = _run(
        _request(
          dive,
          branchSeconds: bottomEndT, // 50% at 45 m: a ppO2 answer, not advice
          interventions: const [
            SwitchGasIntervention(tank: ExistingTankRef('deco50')),
          ],
        ),
      );
      final i = o.branch.index;
      expect(
        o.counterfactual.cnsCurve!.sublist(0, i + 1),
        o.actual.cnsCurve!.sublist(0, i + 1),
      );
      expect(
        o.counterfactual.cnsCurve!.last,
        greaterThan(o.actual.cnsCurve!.last),
      );
      final pp = o.deltas.firstWhere(
        (d) => d.metric == DeltaMetric.maxPpO2AfterBranch,
      );
      expect(pp.counterfactual!, greaterThan(2.0));
    });

    test('shareGas: back gas ends lower', () {
      final base = _run(_request(dive, branchSeconds: branchT));
      final o = _run(
        _request(
          dive,
          branchSeconds: branchT,
          interventions: const [ShareGasIntervention()],
        ),
      );
      final baseEnd = base.consumption.counterfactualFor('back')!;
      final shared = o.consumption.counterfactualFor('back')!;
      expect(shared.endPressureBar!, lessThan(baseEnd.endPressureBar!));
      expect(shared.source, PressureSource.estimated);
    });
  });

  group('re-plan', () {
    test('continuity: tissue curves equal the actual at the branch', () {
      final o = _run(
        _request(dive, branchSeconds: branchT, mode: ScenarioMode.replan),
      );
      expect(o.mode, ScenarioMode.replan);
      final i = o.branch.index;
      expect(
        o.counterfactualTimestamps.sublist(0, i + 1),
        dive.timestamps.sublist(0, i + 1),
      );
      expect(
        o.counterfactual.gfCurve!.sublist(0, i + 1),
        o.actual.gfCurve!.sublist(0, i + 1),
      );
      expect(
        o.counterfactual.ceilingCurve.sublist(0, i + 1),
        o.actual.ceilingCurve.sublist(0, i + 1),
      );
      expect(
        o.counterfactual.decoStatuses[i].compartments,
        o.actual.decoStatuses[i].compartments,
      );
      expect(o.planOutcome, isNotNull);
      expect(o.counterfactualDepths.last, 0);
      for (var k = 1; k < o.counterfactualTimestamps.length; k++) {
        expect(
          o.counterfactualTimestamps[k],
          greaterThan(o.counterfactualTimestamps[k - 1]),
        );
      }
    });

    test('ascendNow from mid-bottom ends sooner than the actual dive', () {
      final o = _run(
        _request(
          dive,
          branchSeconds: branchT,
          interventions: const [AscendNowIntervention()],
        ),
      );
      final runtime = o.deltas.firstWhere(
        (d) => d.metric == DeltaMetric.runtime,
      );
      expect(runtime.delta!, lessThan(0));
      expect(
        o.flags.any((f) => f.kind == ScenarioFlagKind.noBottomRemaining),
        isFalse,
      );
    });

    test('loseTank never shortens deco; earlier ascent never lengthens', () {
      final base = _run(
        _request(dive, branchSeconds: branchT, mode: ScenarioMode.replan),
      );
      final lost = _run(
        _request(
          dive,
          branchSeconds: branchT,
          mode: ScenarioMode.replan,
          interventions: const [LoseTankIntervention(tankId: 'deco50')],
        ),
      );
      expect(
        lost.planOutcome!.totalDecoSeconds,
        greaterThanOrEqualTo(base.planOutcome!.totalDecoSeconds),
      );
      final earlier = _run(
        _request(
          dive,
          branchSeconds: branchT,
          interventions: const [ShiftAscentIntervention(deltaSeconds: -300)],
        ),
      );
      expect(
        earlier.planOutcome!.totalDecoSeconds,
        lessThanOrEqualTo(base.planOutcome!.totalDecoSeconds),
      );
      expect(
        earlier.planOutcome!.runtimeSeconds,
        lessThan(base.planOutcome!.runtimeSeconds),
      );
    });

    test('raising GF-high never raises TTS', () {
      final base = _run(
        _request(dive, branchSeconds: branchT, mode: ScenarioMode.replan),
      );
      final looser = _run(
        _request(
          dive,
          branchSeconds: branchT,
          mode: ScenarioMode.replan,
          interventions: const [ChangeGfIntervention(gfLow: 30, gfHigh: 90)],
        ),
      );
      expect(
        looser.planOutcome!.ttsAtBottom,
        lessThanOrEqualTo(base.planOutcome!.ttsAtBottom),
      );
      expect(
        looser.planOutcome!.totalDecoSeconds,
        lessThanOrEqualTo(base.planOutcome!.totalDecoSeconds),
      );
    });

    test('branch during the ascent flags no bottom and still completes', () {
      final o = _run(
        _request(
          dive,
          branchSeconds: bottomEndT + 120,
          mode: ScenarioMode.replan,
        ),
      );
      expect(
        o.flags.any((f) => f.kind == ScenarioFlagKind.noBottomRemaining),
        isTrue,
      );
      expect(o.counterfactualDepths.last, 0);
      expect(o.planOutcome, isNotNull);
    });

    test('consumption after the branch follows the plan tanks and SAC', () {
      final o = _run(
        _request(dive, branchSeconds: branchT, mode: ScenarioMode.replan),
      );
      final back = o.consumption.counterfactualFor('back')!;
      expect(
        back.startPressureBar,
        closeTo(o.branch.pressureFor('back')!, 1e-9),
      );
      expect(back.endPressureBar!, lessThan(back.startPressureBar!));
      expect(o.consumption.counterfactualFor('deco50'), isNotNull);
    });
  });

  test('runScenarioEngine is the top-level compute entry', () {
    final o = runScenarioEngine(_request(dive, branchSeconds: branchT));
    expect(o.actual.decoStatuses, isNotEmpty);
  });
}
