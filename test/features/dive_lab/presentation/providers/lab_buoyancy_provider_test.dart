import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_intervention.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_mode.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_settings.dart';
import 'package:submersion/features/dive_lab/domain/services/scenario_engine.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_buoyancy_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

import '../../domain/support/synthetic_dives.dart';

LabRequestInputs _inputs() {
  final d = squareDive();
  final profile = [
    for (var i = 0; i < d.depths.length; i++)
      DiveProfilePoint(timestamp: d.timestamps[i], depth: d.depths[i]),
  ];
  return LabRequestInputs(
    dive: Dive(
      id: 'd',
      diveNumber: 1,
      dateTime: DateTime(2026),
      tanks: d.tanks,
      waterType: WaterType.salt,
      profile: profile,
    ),
    profile: profile,
    depths: d.depths,
    timestamps: d.timestamps,
    diveMode: DiveMode.oc,
    tanks: d.tanks,
    gasSwitches: d.switches,
    tankPressures: d.tankPressures,
    startCns: 0,
    startOtu: 0,
    settings: const ScenarioSettings(),
  );
}

void main() {
  final model = WeightPredictionEngine.fit(
    observations: const [],
    gearById: (_) => null,
    bodyWeightKg: 75,
  );

  test('buildCounterfactualTwinInput swaps the profile and tank pressures', () {
    final inputs = _inputs();
    final outcome = const ScenarioEngine().run(
      inputs.toRequest(
        DiveScenario(
          id: 's',
          diveId: 'd',
          name: 'n',
          branchSeconds: 900,
          mode: ScenarioMode.replan,
          interventions: const [AscendNowIntervention()],
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      ),
    );
    final actual = BuoyancyTwinAssembler.assemble(
      dive: inputs.dive,
      tankPressures: const {},
      model: model,
      bodyWeightKg: 75,
    )!;
    final cf = buildCounterfactualTwinInput(actual: actual, outcome: outcome);
    expect(cf.profile.length, outcome.counterfactualTimestamps.length);
    expect(cf.profile.last.depthM, 0);
    final back = cf.tanks.firstWhere((t) => t.id == 'back');
    expect(
      back.endPressureBar,
      outcome.consumption.counterfactualFor('back')!.endPressureBar,
    );
    expect(back.pressureSeries, isNull);
    expect(cf.suit, actual.suit);
  });

  test('labBuoyancyProvider compares both timelines', () async {
    final inputs = _inputs();
    final c = ProviderContainer(
      overrides: [
        labRequestInputsProvider('d').overrideWith((ref) async => inputs),
        scenarioOutcomeProvider('d').overrideWith(
          (ref) async => const ScenarioEngine().run(
            inputs.toRequest(
              DiveScenario(
                id: 's',
                diveId: 'd',
                name: 'n',
                branchSeconds: 900,
                mode: ScenarioMode.replan,
                interventions: const [AscendNowIntervention()],
                createdAt: DateTime(2026),
                updatedAt: DateTime(2026),
              ),
            ),
          ),
        ),
        weightCalibrationProvider.overrideWith((ref) async => model),
        tankPressuresProvider('d').overrideWith((ref) async => const {}),
        latestDiverWeightProvider.overrideWith((ref) async => null),
        labTwinRunnerProvider.overrideWithValue(
          (input) async => runBuoyancyTwin(input),
        ),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(labBuoyancyProvider('d'), (_, _) {});
    addTearDown(sub.close);
    final comparison = await c.read(labBuoyancyProvider('d').future);
    expect(comparison, isNotNull);
    expect(comparison!.actual.verdict.netKg.isFinite, isTrue);
    expect(comparison.counterfactual.verdict.netKg.isFinite, isTrue);
  });
}
