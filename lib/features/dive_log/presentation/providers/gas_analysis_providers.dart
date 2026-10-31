import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Provider for the GasAnalysisService singleton.
///
/// Watches the gas model so flipping the preference rebuilds the service and
/// invalidates every SAC provider downstream of it (issue #828).
final gasAnalysisServiceProvider = Provider<GasAnalysisService>((ref) {
  return GasAnalysisService(gasModel: ref.watch(gasModelProvider));
});

/// Provider for gas-switch based SAC segments
///
/// Returns null if no gas switches are recorded for the dive.
final gasSwitchSegmentsProvider =
    FutureProvider.family<List<SacSegment>?, String>((ref, diveId) async {
      final dive = await ref.watch(diveProvider(diveId).future);
      if (dive == null || dive.profile.isEmpty) return null;

      final gasSwitches = await ref.watch(gasSwitchesProvider(diveId).future);
      if (gasSwitches.isEmpty) return null;

      final tankPressures = await ref.watch(
        tankPressuresProvider(diveId).future,
      );

      final service = ref.watch(gasAnalysisServiceProvider);
      return service.calculateGasSwitchSegments(
        profile: dive.profile,
        tanks: dive.tanks,
        gasSwitches: gasSwitches,
        tankPressures: tankPressures.isEmpty ? null : tankPressures,
      );
    });

/// Provider for depth-phase based SAC segments
///
/// Automatically detects dive phases: descent, bottom, ascent, safety stop.
final phaseSegmentsProvider = FutureProvider.family<List<SacSegment>?, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  if (dive == null || dive.profile.isEmpty) return null;

  final gasSwitches = await ref.watch(gasSwitchesProvider(diveId).future);
  final tankPressures = await ref.watch(tankPressuresProvider(diveId).future);

  final service = ref.watch(gasAnalysisServiceProvider);
  return service.calculatePhaseSegments(
    profile: dive.profile,
    tanks: dive.tanks,
    tankPressures: tankPressures.isEmpty ? null : tankPressures,
    gasSwitches: gasSwitches.isEmpty ? null : gasSwitches,
  );
});

/// Provider for per-cylinder SAC calculations
///
/// Returns SAC metrics for each tank used in the dive.
final cylinderSacProvider = FutureProvider.family<List<CylinderSac>, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  if (dive == null) return [];

  final gasSwitches = await ref.watch(gasSwitchesProvider(diveId).future);
  final tankPressures = await ref.watch(tankPressuresProvider(diveId).future);

  final service = ref.watch(gasAnalysisServiceProvider);
  return service.calculateCylinderSac(
    dive: dive,
    profile: dive.profile,
    gasSwitches: gasSwitches.isEmpty ? null : gasSwitches,
    tankPressures: tankPressures.isEmpty ? null : tankPressures,
  );
});

/// Provider to check if the dive has multiple tanks
final isMultiTankDiveProvider = FutureProvider.family<bool, String>((
  ref,
  diveId,
) async {
  final dive = await ref.watch(diveProvider(diveId).future);
  return dive != null && dive.tanks.length > 1;
});

/// Expanded state for the Gas Analysis section in dive details
final gasAnalysisSectionExpandedProvider = StateProvider<bool>((ref) => false);
