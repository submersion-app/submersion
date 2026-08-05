import 'package:submersion/core/buoyancy/gear_buoyancy_traits.dart';
import 'package:submersion/core/buoyancy/gear_feature.dart';
import 'package:submersion/core/buoyancy/weight_observation.dart';
import 'package:submersion/core/buoyancy/weight_prediction_engine.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/features/equipment/domain/constants/equipment_attribute_catalog.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_planner/presentation/providers/dive_planner_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_attribute.dart';
import 'package:submersion/features/equipment/domain/entities/equipment_item.dart';
import 'package:submersion/features/equipment/presentation/providers/equipment_providers.dart';
import 'package:submersion/features/weight_planner/data/repositories/weight_history_repository.dart';

/// Converts an equipment item to an engine feature.
///
/// Returns null for the excluded types: lead ([EquipmentType.weights]) is
/// the predicted quantity, and tanks are modeled from the tank list.
GearFeature? gearFeatureFor(EquipmentItem item) {
  if (item.type == EquipmentType.weights || item.type == EquipmentType.tank) {
    return null;
  }
  // Index the curated attributes once. attrText/attrNum are each an O(n)
  // scan, and reading them individually would rescan thickness_mm three
  // times; putIfAbsent preserves their first-match semantics.
  final attrs = <String, EquipmentAttribute>{};
  for (final a in item.attributes) {
    if (!a.isCustom) attrs.putIfAbsent(a.key, () => a);
  }
  final thicknessText = attrs[EquipmentAttrKeys.thicknessMm]?.valueText;
  return GearFeature.fromEquipment(
    id: item.id,
    type: item.type,
    name: item.name,
    size: attrs[EquipmentAttrKeys.size]?.valueText,
    thickness: thicknessText,
    buoyancyKg: attrs[EquipmentAttrKeys.buoyancyKg]?.valueNum,
    weightKg: attrs[EquipmentAttrKeys.dryWeightKg]?.valueNum,
    traits: GearBuoyancyTraits(
      primaryThicknessMm: attrs[EquipmentAttrKeys.thicknessMm]?.valueNum,
      panelThicknessesMm: thicknessText == null
          ? const []
          : GearBuoyancyTraits.parsePanelsMm(thicknessText),
      suitStyle: attrs[EquipmentAttrKeys.suitStyle]?.valueText,
      shellMaterial: attrs[EquipmentAttrKeys.shellMaterial]?.valueText,
      bcdStyle: attrs[EquipmentAttrKeys.bcdStyle]?.valueText,
      liftCapacityKg: attrs[EquipmentAttrKeys.liftCapacityKg]?.valueNum,
      gloveType: attrs[EquipmentAttrKeys.gloveType]?.valueText,
    ),
  );
}

/// A weak zero-prior feature for gear ids that no longer resolve (deleted
/// items): their dives still inform the personal term without inventing a
/// buoyancy prior.
GearFeature unknownGearFeature(String id) => GearFeature(
  id: id,
  label: 'Unknown gear',
  priorKg: 0.0,
  priorStrength: 2.0,
  dryMassKg: 0.5,
);

final weightHistoryRepositoryProvider = Provider<WeightHistoryRepository>((
  ref,
) {
  return WeightHistoryRepository();
});

/// The active diver's weight-bearing dive history, oldest first.
///
/// Self-invalidates on any dives-table change (edits, imports, sync).
final weightObservationsProvider = FutureProvider<List<WeightObservation>>((
  ref,
) async {
  final repository = ref.watch(weightHistoryRepositoryProvider);
  final diverId = await ref.watch(validatedCurrentDiverIdProvider.future);
  if (diverId == null) return const [];

  ref.invalidateSelfWhen(DiveRepository().watchDivesChanges());

  return repository.observationsForDiver(diverId);
});

/// The fitted per-diver weight model. Refits whenever the history, the
/// gear list, or the body-weight history changes.
final weightCalibrationProvider = FutureProvider<FittedWeightModel>((
  ref,
) async {
  final observations = await ref.watch(weightObservationsProvider.future);
  final equipment = await ref.watch(allEquipmentProvider.future);
  final latestWeight = await ref.watch(latestDiverWeightProvider.future);

  final itemsById = {for (final item in equipment) item.id: item};

  return WeightPredictionEngine.fit(
    observations: observations,
    gearById: (id) {
      final item = itemsById[id];
      if (item == null) return unknownGearFeature(id);
      return gearFeatureFor(item);
    },
    bodyWeightKg: latestWeight?.weightKg,
  );
});

/// Live prediction for the plan being edited (Gear & Weights section).
///
/// Null while the calibration inputs are still loading. Water type is not
/// part of the plan editing state, so plan predictions use the salt-water
/// baseline; the standalone Weight Planner tool has an explicit control.
final planWeightPredictionProvider = Provider<WeightPrediction?>((ref) {
  final state = ref.watch(divePlanNotifierProvider);
  final model = ref.watch(weightCalibrationProvider).valueOrNull;
  final equipment = ref.watch(allEquipmentProvider).valueOrNull;
  final latestWeight = ref.watch(latestDiverWeightProvider).valueOrNull;
  if (model == null || equipment == null) return null;

  final itemsById = {for (final item in equipment) item.id: item};
  final gear = <GearFeature>[
    for (final id in state.equipmentIds)
      if (itemsById[id] case final item?) ?gearFeatureFor(item),
  ];
  final tanks = [
    for (final tank in state.tanks)
      TankSpec(
        presetName: tank.presetName,
        volumeL: tank.volume,
        workingPressureBar: tank.workingPressure,
        material: tank.material,
      ),
  ];

  return model.predict(
    RigSpec(
      gear: gear,
      tanks: tanks,
      waterType: null,
      bodyWeightKg: latestWeight?.weightKg,
    ),
  );
});
