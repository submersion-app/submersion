import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_request.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';

import '../support/synthetic_dives.dart';

const _bailout = DiveTank(
  id: 'bo',
  name: 'Bailout',
  volume: 11,
  workingPressure: 207,
  startPressure: 200,
  gasMix: GasMix(o2: 21),
  role: TankRole.bailout,
  order: 1,
);

ScenarioRequest _loopRequest(
  SyntheticDive d, {
  required DiveMode mode,
  required int branchSeconds,
  ScenarioMode scenarioMode = ScenarioMode.replay,
  List<ScenarioIntervention> interventions = const [],
  double? scrInjectionRate,
  double? scrSupplyO2Percent,
}) => ScenarioRequest(
  diveId: 'd',
  depths: d.depths,
  timestamps: d.timestamps,
  diveMode: mode,
  tanks: [...d.tanks, _bailout],
  gasSwitches: const [],
  tankPressures: const {},
  loopGasSegments: mode == DiveMode.ccr
      ? const [
          ProfileGasSegment(
            startTimestamp: 0,
            fN2: 0.79,
            fHe: 0,
            setpoint: 1.3,
          ),
        ]
      : null,
  setpointHigh: mode == DiveMode.ccr ? 1.3 : null,
  scrInjectionRate: scrInjectionRate,
  scrSupplyO2Percent: scrSupplyO2Percent,
  startCns: 0,
  startOtu: 0,
  settings: const ScenarioSettings(),
  scenario: DiveScenario(
    id: 's',
    diveId: 'd',
    name: 'n',
    branchSeconds: branchSeconds,
    mode: scenarioMode,
    interventions: interventions,
    createdAt: DateTime(2026, 9, 26),
    updatedAt: DateTime(2026, 9, 26),
  ),
);

void main() {
  final d = squareDive(depth: 40, bottomMinutes: 25, withDeco50: false);

  test('an SCR dive is analysed with its injection model', () {
    // No measured loop ppO2: without the SCR parameters the analysis cannot
    // know the loop ppO2 and reports zero, which is what dive detail avoids.
    final outcome = const ScenarioEngine().run(
      _loopRequest(
        d,
        mode: DiveMode.scr,
        branchSeconds: 900,
        scrInjectionRate: 10,
        scrSupplyO2Percent: 50,
      ),
    );
    final atBottom = d.timestamps.indexOf(900);
    expect(outcome.actual.ppO2Curve[atBottom], greaterThan(0.5));
    expect(outcome.actual.cnsCurve!.last, greaterThan(0));
  });

  for (final mode in [ScenarioMode.replay, ScenarioMode.replan]) {
    test('a CCR bailout breathes open circuit after the branch ($mode)', () {
      final outcome = const ScenarioEngine().run(
        _loopRequest(
          d,
          mode: DiveMode.ccr,
          branchSeconds: 900,
          scenarioMode: mode,
          interventions: const [BailOutIntervention()],
        ),
      );
      final branch = outcome.branch.index;
      // Before the branch the loop holds its 1.3 bar setpoint.
      expect(outcome.counterfactual.ppO2Curve[branch - 5], closeTo(1.3, 0.05));
      // Just after it the diver breathes air at 40 m: about 1.05 bar.
      final after = outcome.counterfactualTimestamps.indexWhere(
        (t) => t > outcome.branch.runtimeSeconds + 30,
      );
      expect(outcome.counterfactual.ppO2Curve[after], lessThan(1.2));
      expect(
        outcome.counterfactualGasSegments
            .where((g) => g.startTimestamp >= outcome.branch.runtimeSeconds)
            .every((g) => g.setpoint == null),
        isTrue,
      );
    });
  }

  test('an SCR re-plan keeps the SCR loop ppO2 after the branch', () {
    final outcome = const ScenarioEngine().run(
      _loopRequest(
        d,
        mode: DiveMode.scr,
        branchSeconds: 900,
        scenarioMode: ScenarioMode.replan,
        scrInjectionRate: 10,
        scrSupplyO2Percent: 50,
      ),
    );
    final branch = outcome.branch.index;
    final atBranch = outcome.actual.ppO2Curve[branch];
    // Still on the bottom a minute later: same depth, same SCR loop ppO2,
    // not the 1.3 bar CCR setpoint the plan would default to.
    final after = outcome.counterfactualTimestamps.indexWhere(
      (t) => t >= outcome.branch.runtimeSeconds + 60,
    );
    expect(outcome.counterfactual.ppO2Curve[after], closeTo(atBranch, 0.05));
    expect(
      (outcome.counterfactual.ppO2Curve[after] - 1.3).abs(),
      greaterThan(0.1),
    );
  });
}
