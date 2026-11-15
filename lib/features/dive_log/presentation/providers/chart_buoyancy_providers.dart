import 'package:flutter/foundation.dart' show compute;

import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/divers/presentation/providers/diver_weight_entry_providers.dart';
import 'package:submersion/features/weight_planner/presentation/providers/weight_planner_providers.dart';

/// Whether the buoyancy model can run for [diveId] at all: it has a tank or
/// an exposure suit (issue #4593).
///
/// Reads the dive only, so a profile surface can offer the buoyancy line
/// without running the simulation; the dashboard's preview renders on the
/// app's first frame and must not pay for a line that is switched off.
final buoyancyModelableProvider = FutureProvider.autoDispose
    .family<bool, String>((ref, diveId) async {
      retainDiveData(ref);
      final dive = await ref.watch(diveProvider(diveId).future);
      return dive != null && BuoyancyTwinAssembler.isModelable(dive);
    });

/// The buoyancy model for the series the profile chart draws (issue #4593).
///
/// A single-source dive, or a Combine's sequential halves, draws the merged
/// profile: that is what the Buoyancy card models, so its result is reused
/// and the dive page computes the model once. On a multi-source dive the
/// chart draws one computer's own samples, so the model runs on those points
/// and that computer's tank pressures, primary or not. The card's query and
/// the per-source one are different reads, and pairing one computer's
/// buoyancy with another's depth is the mistake this avoids.
///
/// Null when there is nothing to model (no tanks and no suit).
final chartBuoyancyTwinProvider = FutureProvider.autoDispose
    .family<BuoyancyTwinResult?, String>((ref, diveId) async {
      retainDiveData(ref);
      final active = ref.watch(activeSourceProfileProvider(diveId));
      if (active == null) {
        final outcome = await ref.watch(buoyancyTwinProvider(diveId).future);
        return outcome?.result;
      }

      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null) return null;
      final tankPressures = await ref.watch(
        activeSourceTankPressuresProvider(diveId).future,
      );
      final model = await ref.watch(weightCalibrationProvider.future);
      final latestWeight = await ref.watch(latestDiverWeightProvider.future);

      final input = BuoyancyTwinAssembler.assemble(
        dive: dive.copyWith(profile: active.points),
        tankPressures: tankPressures,
        model: model,
        bodyWeightKg: latestWeight?.weightKg,
      );
      if (input == null) return null;
      return compute(runBuoyancyTwin, input);
    });
