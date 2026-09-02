import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// Interior-sample spacing (seconds) for constant-depth plan segments so the
/// anchor detector has a sustained run to find at a stop.
const int _kInteriorSampleSeconds = 30;

/// Builds a square-ish profile from plan segments: one sample per boundary
/// plus an interior sample every [_kInteriorSampleSeconds] on constant-depth
/// segments (bottom, stops). Timestamps are cumulative and monotonic.
List<TwinProfileSample> synthesizePlanProfile(List<PlanSegment> segments) {
  final samples = <TwinProfileSample>[];
  if (segments.isEmpty) return samples;
  samples.add(
    TwinProfileSample(timestamp: 0, depthM: segments.first.startDepth),
  );
  var t = 0;
  for (final seg in segments) {
    // A zero- or negative-duration leg adds no time (the segment editor
    // defaults a blank/invalid duration field to 0). Emitting its end
    // boundary would duplicate the previous sample's timestamp and break the
    // monotonic invariant, so skip it.
    if (seg.durationSeconds <= 0) continue;
    final start = t;
    t += seg.durationSeconds;
    if (seg.startDepth == seg.endDepth &&
        seg.durationSeconds > _kInteriorSampleSeconds) {
      for (
        var s = start + _kInteriorSampleSeconds;
        s < t;
        s += _kInteriorSampleSeconds
      ) {
        samples.add(TwinProfileSample(timestamp: s, depthM: seg.startDepth));
      }
    }
    samples.add(TwinProfileSample(timestamp: t, depthM: seg.endDepth));
  }
  return samples;
}

/// Forward buoyancy twin for the plan being edited. Recomputes synchronously
/// on plan edits (plans have few segments; no isolate needed). Null when the
/// plan has no tanks or no resolvable lead.
final planBuoyancyTwinProvider = Provider<BuoyancyTwinOutcome?>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final model = ref.watch(weightCalibrationProvider).valueOrNull;
  final equipment = ref.watch(allEquipmentProvider).valueOrNull;
  final latestWeight = ref.watch(latestDiverWeightProvider).valueOrNull;
  final planResult = ref.watch(planResultsProvider);
  final prediction = ref.watch(planWeightPredictionProvider);

  if (model == null || equipment == null || state.tanks.isEmpty) return null;

  // Both branches are the same quantity: plannedWeightKg is only ever written
  // as a snapshot of prediction.totalKg (see plan_gear_weights_section), and
  // the prediction is a TOTAL trained on observations whose carriedKg now
  // includes ballast built into the rig (issue #1103). Do not add
  // EquipmentLead here -- gear lead is already inside this figure, and adding
  // it again would double-count every rig the model has seen.
  final lead = state.plannedWeightKg ?? prediction?.totalKg ?? 0.0;
  if (lead <= 0) return null;

  final itemsById = {for (final e in equipment) e.id: e};
  final items = <EquipmentItem>[
    for (final id in state.equipmentIds) ?itemsById[id],
  ];

  final consumptionByTank = {
    for (final g in planResult.gasConsumptions) g.tankId: g,
  };
  final tanks = <TwinTankInput>[
    for (final t in state.tanks)
      TwinTankInput(
        id: t.id,
        // 'tank' is a stable key localized by the breakdown widget's
        // _termLabel (like 'suit'/'lead'), not a display string -- a hardcoded
        // 'Tank' would leak English on localized UIs. Real preset/user names
        // pass through untranslated, as intended.
        label: t.presetName ?? t.name ?? 'tank',
        presetName: t.presetName,
        volumeL: t.volume,
        workingPressureBar: t.workingPressure,
        material: t.material,
        o2Percent: t.gasMix.o2,
        hePercent: t.gasMix.he,
        startPressureBar: consumptionByTank[t.id]?.startPressure,
        endPressureBar: consumptionByTank[t.id]?.remainingPressure,
      ),
  ];

  final rig = BuoyancyTwinAssembler.composeRigTerms(
    items: items,
    tanks: tanks,
    model: model,
    waterType:
        WaterType.salt, // plan state carries no water type; salt baseline
    bodyWeightKg: latestWeight?.weightKg,
  );

  // Some planned lead may be non-ditchable (e.g. backplate/trim). When the
  // planner carries a per-WeightType placement, count only the droppable
  // (belt + integrated) portion; otherwise assume all lead is droppable.
  //
  // PlacementPredictor builds that map by splitting the whole predicted total
  // across the diver's habitual placement fractions, which since #1103 are
  // learned from observations that include styled gear ballast. The gear's
  // ditchable share is therefore already inside this figure; adding
  // EquipmentLead.droppableKg on top would count it twice.
  final placement = state.plannedWeightPlacement;
  final droppableLead = placement == null
      ? lead
      : BuoyancyTwinAssembler.droppableLeadFromPlacement(placement);

  final input = TwinInput(
    profile: synthesizePlanProfile(state.segments),
    tanks: tanks,
    suit: rig.suit,
    staticTerms: rig.staticTerms,
    leadKg: lead,
    droppableLeadKg: droppableLead,
    environment: DiveEnvironment.forConditions(
      altitudeMeters: state.altitude,
      waterType:
          WaterType.salt, // salt baseline, matching composeRigTerms above
    ),
    totalMassKg: rig.totalMassKg,
  );

  final wing = items
      .where((e) => e.type == EquipmentType.bcd && e.liftCapacityKg != null)
      .map((e) => e.liftCapacityKg)
      .firstOrNull;

  final result = runBuoyancyTwin(input);
  return BuoyancyTwinOutcome(
    result: result,
    outputs: TwinAnalyzer.analyze(result),
    wingLiftCapacityKg: wing,
  );
});
