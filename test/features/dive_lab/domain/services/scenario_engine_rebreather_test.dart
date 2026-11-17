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
  double? replanScrVo2,
  ScenarioSettings settings = const ScenarioSettings(),
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
  replanScrVo2: replanScrVo2,
  startCns: 0,
  startOtu: 0,
  settings: settings,
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

  group('the re-plan VO2 (#4660)', () {
    double tailPpO2({double? replanScrVo2, required double diverDefault}) {
      final outcome = const ScenarioEngine().run(
        _loopRequest(
          d,
          mode: DiveMode.scr,
          branchSeconds: 900,
          scenarioMode: ScenarioMode.replan,
          scrInjectionRate: 10,
          scrSupplyO2Percent: 50,
          replanScrVo2: replanScrVo2,
          settings: ScenarioSettings(defaultScrVo2Lpm: diverDefault),
        ),
      );
      final after = outcome.counterfactualTimestamps.indexWhere(
        (t) => t >= outcome.branch.runtimeSeconds + 60,
      );
      return outcome.counterfactual.ppO2Curve[after];
    }

    test('a dive with no VO2 of its own re-plans at the diver default', () {
      // EAN50 at 10 L/min: loop FO2 0.425 at VO2 1.3, 0.375 at VO2 2.0.
      final atDefault13 = tailPpO2(diverDefault: 1.3);
      final atDefault20 = tailPpO2(diverDefault: 2.0);
      expect(atDefault20, lessThan(atDefault13 - 0.1));
    });

    test('a dive with no logged rate still gets an SCR tail', () {
      // Older SCR dives stored no injection rate; the re-plan breathes the
      // diver's default, so the tail must show that loop, not zero.
      final outcome = const ScenarioEngine().run(
        _loopRequest(
          d,
          mode: DiveMode.scr,
          branchSeconds: 900,
          scenarioMode: ScenarioMode.replan,
          scrSupplyO2Percent: 50,
        ),
      );
      final after = outcome.counterfactualTimestamps.indexWhere(
        (t) => t >= outcome.branch.runtimeSeconds + 60,
      );
      expect(outcome.counterfactual.ppO2Curve[after], greaterThan(1.0));
    });

    test('a dive VO2 of its own wins over the diver default', () {
      expect(
        tailPpO2(replanScrVo2: 1.3, diverDefault: 2.0),
        closeTo(tailPpO2(diverDefault: 1.3), 1e-9),
      );
    });
  });

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

  test('an SCR re-plan stays in the dive\'s own pressure (#3958)', () {
    final outcome = const ScenarioEngine().run(
      _loopRequest(
        d,
        mode: DiveMode.scr,
        branchSeconds: 900,
        scenarioMode: ScenarioMode.replan,
        scrInjectionRate: 10,
        scrSupplyO2Percent: 50,
        settings: const ScenarioSettings(
          altitudeMeters: 3000,
          waterType: WaterType.fresh,
        ),
      ),
    );
    final after = outcome.counterfactualTimestamps.indexWhere(
      (t) => t >= outcome.branch.runtimeSeconds + 60,
    );

    // The same depth on the same loop, so the tail must not step up to the
    // flat model at the branch.
    expect(
      outcome.counterfactual.ppO2Curve[after],
      closeTo(outcome.actual.ppO2Curve[outcome.branch.index], 0.05),
    );
  });
}
