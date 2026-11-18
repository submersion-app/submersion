import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// The buoyancy twin for one dive, computed on demand.
///
/// The rig (typed dive_weights, linked equipment, tanks, water type) comes
/// from the fully-hydrated [diveProvider] -- the lean analysis hydration drops
/// weights and equipment, so it must not be used here. The profile samples
/// come from [diveProfileProvider], which is isPrimary-filtered so an edited
/// or multi-computer dive is not double-counted (#536).
///
/// Returns null when the dive is unmodelable (no tanks and no exposure suit,
/// e.g. apnea). The heavy simulation runs in an isolate via `compute`. All
/// upstream providers self-invalidate on the relevant database changes, so no
/// extra watchers are needed here.
final buoyancyTwinProvider = FutureProvider.autoDispose
    .family<BuoyancyTwinOutcome?, String>((ref, diveId) async {
      retainDiveData(ref);
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null) return null;

      final (profile, tankPressures) = await (
        ref.watch(diveProfileProvider(diveId).future),
        ref.watch(tankPressuresProvider(diveId).future),
      ).wait;
      final result = await runBuoyancyTwinFor(
        ref,
        dive: dive,
        profile: profile,
        tankPressures: tankPressures,
      );
      if (result == null) return null;

      final wing = dive.equipment
          .where((e) => e.type == EquipmentType.bcd && e.liftCapacityKg != null)
          .firstOrNull;
      return BuoyancyTwinOutcome(
        result: result,
        outputs: TwinAnalyzer.analyze(result),
        wingLiftCapacityKg: wing?.liftCapacityKg,
      );
    });

/// Runs the buoyancy twin for [dive] with [profile] as its samples and
/// [tankPressures] as its gas use, against the diver's calibration and latest
/// body weight. Shared by the Buoyancy card and the profile chart's line
/// (#4593), so both model a dive the same way. Null when there is nothing to
/// model; the simulation itself runs in an isolate.
Future<BuoyancyTwinResult?> runBuoyancyTwinFor(
  Ref ref, {
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required Map<String, List<TankPressurePoint>> tankPressures,
}) async {
  final (model, latestWeight) = await (
    ref.watch(weightCalibrationProvider.future),
    ref.watch(latestDiverWeightProvider.future),
  ).wait;
  final input = BuoyancyTwinAssembler.assemble(
    dive: dive.copyWith(profile: profile),
    tankPressures: tankPressures,
    model: model,
    bodyWeightKg: latestWeight?.weightKg,
  );
  if (input == null) return null;
  return compute(runBuoyancyTwin, input);
}
