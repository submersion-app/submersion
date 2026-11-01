import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/features/dive_log/data/services/gas_analysis_service.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/cylinder_sac.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
import 'package:submersion/features/dive_log/domain/entities/source_profile.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/gas_switch_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_analysis_provider.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';

/// Provider for the GasAnalysisService singleton.
///
/// Watches the gas model so flipping the preference rebuilds the service and
/// invalidates every SAC provider downstream of it (issue #828).
final gasAnalysisServiceProvider = Provider<GasAnalysisService>((ref) {
  return GasAnalysisService(gasModel: ref.watch(gasModelProvider));
});

/// What a segment breakdown reads, for the data source in view.
typedef _SegmentInputs = ({
  List<DiveProfilePoint> profile,
  List<DiveTank> tanks,
  List<GasSwitchWithTank> gasSwitches,
  Map<String, List<TankPressurePoint>> tankPressures,
  DiveEnvironment environment,
});

/// The source whose samples [key] names, or null when the dive has no
/// per-source series. Resolved as [sourceProfileAnalysisProvider] does, so a
/// breakdown never covers a different series from the time chart beside it.
Future<SourceProfile?> _viewedSource(Ref ref, DiveSourceKey key) async {
  final sources = await ref.watch(diveDataSourcesProvider(key.diveId).future);
  if (sources.length < 2) return null;
  final profiles = await ref.watch(sourceProfilesProvider(key.diveId).future);
  if (!usesPerSourceRendering(sources, profiles.values)) return null;
  final source =
      sources.where((s) => s.id == key.sourceId).firstOrNull ??
      primaryDataSource(sources);
  return profiles[source.id];
}

/// Scopes a breakdown to the source in view, by the rule
/// [computeAnalysisForProfile] applies: `dive.profile` interleaves every
/// computer's samples, and a computer's tanks, switches and pressure series
/// are its own.
Future<_SegmentInputs?> _segmentInputs(Ref ref, DiveSourceKey key) async {
  final dive = await ref.watch(diveProvider(key.diveId).future);
  if (dive == null) return null;

  final gasSwitches = await ref.watch(gasSwitchesProvider(key.diveId).future);
  // Watched for a scoped source too: it is what reloads this when a pressure
  // series changes.
  final tankPressures = await ref.watch(
    tankPressuresProvider(key.diveId).future,
  );
  final source = await _viewedSource(ref, key);
  final computerId = source?.computerId;
  if (computerId == null) {
    return (
      profile: source?.points ?? dive.profile,
      tanks: dive.tanks,
      gasSwitches: gasSwitches,
      tankPressures: tankPressures,
      environment: dive.environment,
    );
  }

  final tanks = dive.tanks.where((t) => t.isUsedBy(computerId)).toList();
  final tankIds = {for (final t in tanks) t.id};
  final ownPressures = await ref
      .watch(tankPressureRepositoryProvider)
      .getTankPressuresForComputer(
        key.diveId,
        computerId,
        sourceId: source!.sourceId,
      );
  return (
    profile: source.points,
    tanks: tanks,
    gasSwitches: [
      for (final sw in gasSwitches)
        if (tankIds.contains(sw.gasSwitch.tankId) &&
            sw.gasSwitch.appliesTo(computerId))
          sw,
    ],
    tankPressures: {
      for (final entry in ownPressures.entries)
        if (tankIds.contains(entry.key)) entry.key: entry.value,
    },
    environment: dive.environment,
  );
}

/// Provider for gas-switch based SAC segments
///
/// Returns null if no gas switches are recorded for the dive.
final gasSwitchSegmentsProvider =
    FutureProvider.family<List<SacSegment>?, DiveSourceKey>((ref, key) async {
      final inputs = await _segmentInputs(ref, key);
      if (inputs == null ||
          inputs.profile.isEmpty ||
          inputs.gasSwitches.isEmpty) {
        return null;
      }

      final service = ref.watch(gasAnalysisServiceProvider);
      return service.calculateGasSwitchSegments(
        profile: inputs.profile,
        tanks: inputs.tanks,
        gasSwitches: inputs.gasSwitches,
        tankPressures: inputs.tankPressures.isEmpty
            ? null
            : inputs.tankPressures,
        environment: inputs.environment,
      );
    });

/// Provider for depth-phase based SAC segments
///
/// Automatically detects dive phases: descent, bottom, ascent, safety stop.
final phaseSegmentsProvider =
    FutureProvider.family<List<SacSegment>?, DiveSourceKey>((ref, key) async {
      final inputs = await _segmentInputs(ref, key);
      if (inputs == null || inputs.profile.isEmpty) return null;

      final service = ref.watch(gasAnalysisServiceProvider);
      return service.calculatePhaseSegments(
        profile: inputs.profile,
        tanks: inputs.tanks,
        tankPressures: inputs.tankPressures.isEmpty
            ? null
            : inputs.tankPressures,
        gasSwitches: inputs.gasSwitches.isEmpty ? null : inputs.gasSwitches,
        environment: inputs.environment,
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
