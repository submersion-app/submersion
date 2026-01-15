import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';

/// Provider for the GasAnalysisService singleton
final gasAnalysisServiceProvider = Provider<GasAnalysisService>((ref) {
  return GasAnalysisService();
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

/// Currently selected segmentation method for the SAC segments display
final selectedSegmentationProvider = StateProvider<SacSegmentationType>(
  (ref) => SacSegmentationType.timeInterval,
);

/// Provider that returns the active segments based on selected segmentation method
///
/// This aggregates segments from the appropriate provider based on user selection.
/// Takes a Dive object directly since time-based segments come from ProfileAnalysis.
final activeSegmentsForDiveProvider = Provider.family<List<SacSegment>?, Dive>((
  ref,
  dive,
) {
  final method = ref.watch(selectedSegmentationProvider);

  switch (method) {
    case SacSegmentationType.timeInterval:
    case SacSegmentationType.depthBased:
      // Time-based segments come from the existing profile analysis
      final analysis = ref.watch(diveProfileAnalysisProvider(dive));
      return analysis?.sacSegments;

    case SacSegmentationType.gasSwitch:
      return ref.watch(gasSwitchSegmentsProvider(dive.id)).valueOrNull;

    case SacSegmentationType.depthPhase:
      return ref.watch(phaseSegmentsProvider(dive.id)).valueOrNull;
  }
});

/// Provider to check if gas-switch segmentation is available for a dive
final hasGasSwitchesProvider = FutureProvider.family<bool, String>((
  ref,
  diveId,
) async {
  final gasSwitches = await ref.watch(gasSwitchesProvider(diveId).future);
  return gasSwitches.isNotEmpty;
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

/// Expanded state for the Cylinder SAC subsection
final cylinderSacExpandedProvider = StateProvider<bool>((ref) => false);
