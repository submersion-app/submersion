import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_lab/presentation/providers/lab_request_inputs_provider.dart';
import 'package:submersion/features/dive_lab/presentation/providers/scenario_outcome_provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// The buoyancy twin's verdicts for both timelines.
class BuoyancyComparison {
  const BuoyancyComparison({
    required this.actual,
    required this.counterfactual,
    required this.wingLiftCapacityKg,
  });
  final TwinOutputs actual;
  final TwinOutputs counterfactual;
  final double? wingLiftCapacityKg;
}

typedef TwinRunner = Future<BuoyancyTwinResult> Function(TwinInput input);

/// Runs the twin on a background isolate; tests override it synchronously.
final labTwinRunnerProvider = Provider<TwinRunner>(
  (_) =>
      (input) => compute(runBuoyancyTwin, input),
);

/// The counterfactual twin input: the actual rig over the counterfactual
/// profile, each tank's start and end pressure taken from the consumption
/// pass when known (no measured series: the twin interpolates). Cylinders
/// that exist only in the counterfactual (hypothetical) are not modelled.
TwinInput buildCounterfactualTwinInput({
  required TwinInput actual,
  required ScenarioOutcome outcome,
}) {
  final profile = <TwinProfileSample>[
    for (var i = 0; i < outcome.counterfactualTimestamps.length; i++)
      TwinProfileSample(
        timestamp: outcome.counterfactualTimestamps[i],
        depthM: outcome.counterfactualDepths[i],
      ),
  ];
  final tanks = <TwinTankInput>[
    for (final t in actual.tanks)
      () {
        final c = outcome.consumption.counterfactualFor(t.id);
        return TwinTankInput(
          id: t.id,
          label: t.label,
          presetName: t.presetName,
          volumeL: t.volumeL,
          workingPressureBar: t.workingPressureBar,
          material: t.material,
          o2Percent: t.o2Percent,
          hePercent: t.hePercent,
          startPressureBar: c?.startPressureBar ?? t.startPressureBar,
          endPressureBar: c?.endPressureBar ?? t.endPressureBar,
        );
      }(),
  ];
  return TwinInput(
    profile: profile,
    tanks: tanks,
    suit: actual.suit,
    staticTerms: actual.staticTerms,
    leadKg: actual.leadKg,
    droppableLeadKg: actual.droppableLeadKg,
    environment: actual.environment,
    totalMassKg: actual.totalMassKg,
  );
}

/// Null when the dive is ineligible, the outcome is not ready, or the dive
/// carries neither tanks nor an exposure suit (unmodelable).
final labBuoyancyProvider = FutureProvider.autoDispose
    .family<BuoyancyComparison?, String>((ref, diveId) async {
      final inputs = await ref.watch(labRequestInputsProvider(diveId).future);
      if (inputs == null) return null;
      final outcome = await ref.watch(scenarioOutcomeProvider(diveId).future);
      if (outcome == null) return null;
      final model = await ref.watch(weightCalibrationProvider.future);
      final pressures = await ref.watch(tankPressuresProvider(diveId).future);
      final latest = await ref.watch(latestDiverWeightProvider.future);
      final actualInput = BuoyancyTwinAssembler.assemble(
        dive: inputs.dive.copyWith(profile: inputs.profile),
        tankPressures: pressures,
        model: model,
        bodyWeightKg: latest?.weightKg,
      );
      if (actualInput == null) return null;
      final run = ref.read(labTwinRunnerProvider);
      final actual = await run(actualInput);
      final counterfactual = await run(
        buildCounterfactualTwinInput(actual: actualInput, outcome: outcome),
      );
      double? wing;
      for (final e in inputs.dive.equipment) {
        if (e.type == EquipmentType.bcd && e.liftCapacityKg != null) {
          wing = e.liftCapacityKg;
          break;
        }
      }
      return BuoyancyComparison(
        actual: TwinAnalyzer.analyze(actual),
        counterfactual: TwinAnalyzer.analyze(counterfactual),
        wingLiftCapacityKg: wing,
      );
    });
