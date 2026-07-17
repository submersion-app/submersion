import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/buoyancy/twin_analyzer.dart';
import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// The buoyancy twin for one dive, computed on demand off the primary
/// profile, measured tank pressures, and the diver's calibrated weight model.
///
/// Returns null when the dive is unmodelable (no tanks and no exposure suit,
/// e.g. apnea). The heavy simulation runs in an isolate via `compute`. All
/// upstream providers self-invalidate on the relevant database changes, so no
/// extra watchers are needed here.
final buoyancyTwinProvider =
    FutureProvider.family<BuoyancyTwinOutcome?, String>((ref, diveId) async {
      final dive = await ref.watch(analysisDiveProvider(diveId).future);
      if (dive == null) return null;

      final model = await ref.watch(weightCalibrationProvider.future);
      final tankPressures = await ref.watch(
        tankPressuresProvider(diveId).future,
      );
      final latestWeight = await ref.watch(latestDiverWeightProvider.future);

      final input = BuoyancyTwinAssembler.assemble(
        dive: dive,
        tankPressures: tankPressures,
        model: model,
        bodyWeightKg: latestWeight?.weightKg,
      );
      if (input == null) return null;

      final result = await compute(runBuoyancyTwin, input);
      final wing = dive.equipment
          .where((e) => e.type == EquipmentType.bcd && e.liftCapacityKg != null)
          .firstOrNull;
      return BuoyancyTwinOutcome(
        result: result,
        outputs: TwinAnalyzer.analyze(result),
        wingLiftCapacityKg: wing?.liftCapacityKg,
      );
    });
