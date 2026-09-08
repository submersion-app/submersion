import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/features/dive_log/data/services/estimated_tank_pressure_synthesizer.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    show TankPressurePoint;
import 'package:submersion/features/dive_log/presentation/providers/active_source_provider.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// The tank pressure curves the profile chart surfaces draw.
///
/// A module of its own: [activeSourceTankPressuresProvider] needs
/// `activeSourceProfileProvider`, which already imports `dive_providers`,
/// so neither of these can live there without an import cycle.

/// The per-tank pressure curves the profile chart draws for [diveId]: the
/// active source's computer's own series on a multi-source dive, the plain
/// [tankPressuresProvider] union otherwise.
///
/// Tank-pressure twin of [activeSourceProfileProvider]. Two computers paired
/// to one transmitter both log the same cylinder, and consolidation files
/// both series under one tank because the tanks match on gas mix. The
/// unscoped read interleaves them, and since the two computers sample on
/// offset seconds the single line alternates between them every sample: a
/// fuzzy band wherever they disagree by a fraction of a bar (#543's
/// pressure counterpart). Chart surfaces read this; SAC, exports and the
/// buoyancy twins keep the union, which is every reading the dive holds.
final activeSourceTankPressuresProvider = FutureProvider.autoDispose
    .family<Map<String, List<TankPressurePoint>>, String>((ref, diveId) {
      final active = ref.watch(activeSourceProfileProvider(diveId));
      if (active == null) {
        return ref.watch(tankPressuresProvider(diveId).future);
      }
      final repository = ref.watch(tankPressureRepositoryProvider);
      // Same tick as tankPressuresProvider: tank_pressure_series writes.
      ref.invalidateSelfWhen(
        ref.watch(diveRepositoryProvider).watchAnalysisInputChanges(),
      );
      return repository.getTankPressuresForComputer(diveId, active.computerId);
    });

/// Real per-tank pressures augmented with in-memory linear estimates for tanks
/// that have start/end pressures but no transmitter data. Chart-only; the
/// estimates are never persisted, so SAC analysis and exports (which read the
/// repository directly) still see real measured data only.
final estimatedTankPressuresProvider =
    FutureProvider.family<EstimatedTankPressures, String>((ref, diveId) async {
      // Start the independent fetches concurrently to avoid a request waterfall
      // on the chart load path.
      final realFuture = ref.watch(
        activeSourceTankPressuresProvider(diveId).future,
      );
      final diveFuture = ref.watch(diveProvider(diveId).future);
      final switchesFuture = ref.watch(gasSwitchesProvider(diveId).future);
      // Read synchronously, before the first await, so the dependency is
      // registered while the provider is certainly still alive.
      final showEstimates = ref.watch(
        settingsProvider.select((s) => s.defaultShowEstimatedTankPressure),
      );
      final real = await realFuture;
      final dive = await diveFuture;
      if (dive == null) {
        return EstimatedTankPressures(real, const <String>{});
      }
      // A gauge (bottom-timer) dive models no gas at all, so a synthesized
      // pressure trace would be fabricated rather than measured (issue #731).
      // Real transmitter samples, if the dive has any, still pass through.
      if (dive.isGauge) {
        return EstimatedTankPressures(real, const <String>{});
      }
      // The diver can switch estimates off entirely (issue #731). Gating here
      // rather than at the chart means the series never exists, so no legend
      // chip, tooltip row, or "(est.)" label survives anywhere.
      if (!showEstimates) {
        return EstimatedTankPressures(real, const <String>{});
      }
      final switches = await switchesFuture;
      return synthesizeEstimatedTankPressures(
        existing: real,
        tanks: dive.tanks,
        gasSwitches: switches,
        diveDurationSeconds: dive.profile.isEmpty
            ? 0
            : dive.profile.last.timestamp,
        firstSampleSeconds: dive.profile.isEmpty
            ? 0
            : dive.profile.first.timestamp,
      );
    });
