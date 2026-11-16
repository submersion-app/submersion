import 'package:submersion/core/buoyancy/buoyancy_twin.dart';
import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/buoyancy_twin_assembler.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/buoyancy_twin_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/chart_tank_pressures_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_data_retention.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

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
/// The Buoyancy card models the dive's primary rows. That is the series the
/// chart draws for a single-source dive, for a Combine's sequential halves
/// (each half keeps its own primary series) and for the primary computer of
/// a multi-source dive, so in all three the card's result is reused and the
/// dive page runs the model once. Only a secondary computer is modelled
/// apart, on its own samples and tank pressures, so its line never pairs one
/// computer's buoyancy with another's depth.
///
/// Null when there is nothing to model (no tanks and no suit).
final chartBuoyancyTwinProvider = FutureProvider.autoDispose
    .family<BuoyancyTwinResult?, String>((ref, diveId) async {
      retainDiveData(ref);
      final active = ref.watch(activeSourceProfileProvider(diveId));
      if (active == null || await _drawsPrimary(ref, diveId, active)) {
        final outcome = await ref.watch(buoyancyTwinProvider(diveId).future);
        return outcome?.result;
      }
      // A secondary whose samples have not arrived yet: nothing to model.
      if (active.points.isEmpty) return null;

      final (dive, tankPressures) = await (
        ref.watch(diveProvider(diveId).future),
        ref.watch(activeSourceTankPressuresProvider(diveId).future),
      ).wait;
      if (dive == null) return null;
      return runBuoyancyTwinFor(
        ref,
        dive: dive,
        profile: active.points,
        tankPressures: tankPressures,
      );
    });

/// Whether [active] is the dive's primary source, the one the Buoyancy card
/// models (the first source when none is marked, as the chart resolves it).
Future<bool> _drawsPrimary(Ref ref, String diveId, SourceProfile active) async {
  final sources = await ref.watch(diveDataSourcesProvider(diveId).future);
  final primary =
      sources.where((s) => s.isPrimary).firstOrNull ?? sources.firstOrNull;
  return primary != null && primary.id == active.sourceId;
}
