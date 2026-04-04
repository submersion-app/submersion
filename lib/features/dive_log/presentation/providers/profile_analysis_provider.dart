import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/computer_cns_extractor.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/profile_legend_provider.dart';

/// Reports which data source was actually used for each metric in the current profile.
/// Updated as a side-effect of profileAnalysisProvider.
final metricSourceInfoProvider = StateProvider<MetricSourceInfo?>(
  (ref) => null,
);

/// Provider that loads dive computer events from the database and maps them
/// to domain [ProfileEvent] instances.
final diveComputerEventsProvider =
    FutureProvider.family<List<ProfileEvent>, String>((ref, diveId) async {
      final repository = ref.watch(diveComputerRepositoryProvider);
      final dbEvents = await repository.getEventsForDive(diveId);
      return dbEvents.map(mapDiveProfileEventToProfileEvent).toList();
    });

/// Combines pressure data from multiple tanks into a single pressure series.
///
/// For multi-tank SAC calculation, we need to track total gas consumption across
/// all tanks. This function sums up pressure drops at each timestamp.
///
/// Returns a list of combined pressures aligned with the given timestamps,
/// or null if no multi-tank data is available.
List<double>? _combineMultiTankPressures({
  required List<int> timestamps,
  required Map<String, List<TankPressurePoint>> tankPressures,
  required List<DiveTank> tanks,
}) {
  if (tankPressures.isEmpty || tanks.isEmpty) return null;

  // Build a map of tank volumes for weighting (needed to normalize consumption)
  final tankVolumes = <String, double>{};
  for (final tank in tanks) {
    if (tank.volume != null && tank.volume! > 0) {
      tankVolumes[tank.id] = tank.volume!;
    }
  }

  // If no tank has volume data, we can't properly calculate combined SAC
  if (tankVolumes.isEmpty) return null;

  // For each timestamp, calculate total gas consumption (in liters at surface)
  // from all tanks with pressure data
  final combinedPressures = <double>[];

  for (int i = 0; i < timestamps.length; i++) {
    final targetTime = timestamps[i];
    double totalGasLiters = 0;
    double totalVolume = 0;

    for (final entry in tankPressures.entries) {
      final tankId = entry.key;
      final pressurePoints = entry.value;
      final tankVolume = tankVolumes[tankId];

      if (tankVolume == null || pressurePoints.isEmpty) continue;

      // Find pressure at this timestamp (interpolate if needed)
      double? pressure;
      for (int j = 0; j < pressurePoints.length; j++) {
        if (pressurePoints[j].timestamp == targetTime) {
          pressure = pressurePoints[j].pressure;
          break;
        } else if (pressurePoints[j].timestamp > targetTime) {
          // Interpolate between j-1 and j
          if (j > 0) {
            final p1 = pressurePoints[j - 1];
            final p2 = pressurePoints[j];
            final ratio =
                (targetTime - p1.timestamp) / (p2.timestamp - p1.timestamp);
            pressure = p1.pressure + (p2.pressure - p1.pressure) * ratio;
          } else {
            pressure = pressurePoints[j].pressure;
          }
          break;
        }
      }
      // Use last pressure if timestamp is after all data points
      pressure ??= pressurePoints.last.pressure;

      // Convert pressure to gas in liters: gas_liters = pressure_bar * tank_volume_liters
      totalGasLiters += pressure * tankVolume;
      totalVolume += tankVolume;
    }

    // Convert back to equivalent pressure (normalized by total tank volume)
    // This gives us a single "combined" pressure that represents total gas
    if (totalVolume > 0) {
      combinedPressures.add(totalGasLiters / totalVolume);
    } else {
      combinedPressures.add(0);
    }
  }

  return combinedPressures.isNotEmpty ? combinedPressures : null;
}

/// Placeholder class for logger
class _ProfileAnalysisProvider {}

final _log = LoggerService.forClass(_ProfileAnalysisProvider);

/// Creates a ProfileAnalysisService using dive-specific GF when available,
/// falling back to user settings.
ProfileAnalysisService _resolveAnalysisService(
  Ref ref,
  int? gradientFactorLow,
  int? gradientFactorHigh,
) {
  if (gradientFactorLow != null && gradientFactorHigh != null) {
    return ProfileAnalysisService(
      gfLow: (gradientFactorLow / 100.0).clamp(0.0, 1.0),
      gfHigh: (gradientFactorHigh / 100.0).clamp(0.0, 1.0),
      ppO2WarningThreshold: ref.watch(ppO2MaxWorkingProvider),
      ppO2CriticalThreshold: ref.watch(ppO2MaxDecoProvider),
      cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
      ascentRateWarning: ref.watch(ascentRateWarningProvider),
      ascentRateCritical: ref.watch(ascentRateCriticalProvider),
      lastStopDepth: ref.watch(lastStopDepthProvider),
    );
  }
  return ref.watch(profileAnalysisServiceProvider);
}

/// Overlays computer-reported decompression data onto a calculated
/// [ProfileAnalysis].
///
/// Each metric (NDL, ceiling, TTS, CNS) is independently controlled by its
/// own [MetricDataSource] parameter. When a source is [MetricDataSource.computer]
/// and computer data exists in the profile, those values take priority over
/// the Buhlmann-calculated values. Points without computer data fall back to
/// the calculated values.
///
/// Returns a tuple of the (possibly overlaid) [ProfileAnalysis] and a
/// [MetricSourceInfo] reporting the actual source used per metric after
/// fallback resolution.
(ProfileAnalysis, MetricSourceInfo) overlayComputerDecoData(
  ProfileAnalysis analysis,
  List<DiveProfilePoint> profile, {
  MetricDataSource ndlSource = MetricDataSource.calculated,
  MetricDataSource ceilingSource = MetricDataSource.calculated,
  MetricDataSource ttsSource = MetricDataSource.calculated,
  MetricDataSource cnsSource = MetricDataSource.calculated,
}) {
  final hasComputerNdl = profile.any((p) => p.ndl != null);
  final hasComputerCeiling = profile.any((p) => p.ceiling != null);
  // TTS=0 is a sentinel from dive computers that don't track TTS;
  // treat it as unavailable so we fall back to calculated values.
  final hasComputerTts = profile.any((p) => p.tts != null && p.tts! > 0);
  final hasComputerCns = profile.any((p) => p.cns != null);

  // Decide per-metric: overlay only when source=computer AND data exists
  final useNdl = ndlSource == MetricDataSource.computer && hasComputerNdl;
  final useCeiling =
      ceilingSource == MetricDataSource.computer && hasComputerCeiling;
  final useTts = ttsSource == MetricDataSource.computer && hasComputerTts;
  final useCns = cnsSource == MetricDataSource.computer && hasComputerCns;

  // Report actual source used (fallback to calculated if no data)
  final sourceInfo = (
    ndlActual: useNdl ? MetricDataSource.computer : MetricDataSource.calculated,
    ceilingActual: useCeiling
        ? MetricDataSource.computer
        : MetricDataSource.calculated,
    ttsActual: useTts ? MetricDataSource.computer : MetricDataSource.calculated,
    cnsActual: useCns ? MetricDataSource.computer : MetricDataSource.calculated,
  );

  if (!useNdl && !useCeiling && !useTts && !useCns) {
    return (analysis, sourceInfo);
  }

  final overlaid = analysis.copyWith(
    ndlCurve: useNdl
        ? List<int>.generate(
            profile.length,
            (i) =>
                profile[i].ndl ??
                (i < analysis.ndlCurve.length ? analysis.ndlCurve[i] : 0),
          )
        : null,
    ceilingCurve: useCeiling
        ? List<double>.generate(
            profile.length,
            (i) =>
                profile[i].ceiling ??
                (i < analysis.ceilingCurve.length
                    ? analysis.ceilingCurve[i]
                    : 0.0),
          )
        : null,
    ttsCurve: useTts
        ? List<int>.generate(profile.length, (i) {
            final computerTts = profile[i].tts;
            if (computerTts != null && computerTts > 0) return computerTts;
            if (analysis.ttsCurve != null && i < analysis.ttsCurve!.length) {
              return analysis.ttsCurve![i];
            }
            return 0;
          })
        : null,
    cnsCurve: useCns
        ? List<double>.generate(
            profile.length,
            (i) =>
                profile[i].cns ??
                (analysis.cnsCurve != null && i < analysis.cnsCurve!.length
                    ? analysis.cnsCurve![i]
                    : 0.0),
          )
        : null,
  );

  return (overlaid, sourceInfo);
}

/// Provider for the ProfileAnalysisService configured with user settings
final profileAnalysisServiceProvider = Provider<ProfileAnalysisService>((ref) {
  // Get decompression settings
  final gfLow = ref.watch(gfLowProvider);
  final gfHigh = ref.watch(gfHighProvider);
  final ppO2MaxWorking = ref.watch(ppO2MaxWorkingProvider);
  final ppO2MaxDeco = ref.watch(ppO2MaxDecoProvider);
  final cnsWarningThreshold = ref.watch(cnsWarningThresholdProvider);
  final ascentRateWarning = ref.watch(ascentRateWarningProvider);
  final ascentRateCritical = ref.watch(ascentRateCriticalProvider);
  final lastStopDepth = ref.watch(lastStopDepthProvider);

  return ProfileAnalysisService(
    gfLow: gfLow / 100.0, // Convert from percentage to fraction
    gfHigh: gfHigh / 100.0,
    ppO2WarningThreshold: ppO2MaxWorking,
    ppO2CriticalThreshold: ppO2MaxDeco,
    cnsWarningThreshold: cnsWarningThreshold,
    ascentRateWarning: ascentRateWarning,
    ascentRateCritical: ascentRateCritical,
    lastStopDepth: lastStopDepth,
  );
});

/// Input parameters for running profile analysis on a background isolate.
///
/// All fields must be isolate-safe (primitives, lists, enums, simple classes).
class _ProfileAnalysisInput {
  final double gfLow;
  final double gfHigh;
  final double ppO2WarningThreshold;
  final double ppO2CriticalThreshold;
  final int cnsWarningThreshold;
  final double ascentRateWarning;
  final double ascentRateCritical;
  final double lastStopDepth;
  final String diveId;
  final List<double> depths;
  final List<int> timestamps;
  final double o2Fraction;
  final double heFraction;
  final double startCns;
  final List<double>? pressures;
  final DiveMode diveMode;
  final double? setpointHigh;
  final double? setpointLow;
  final double? scrInjectionRate;
  final double? scrSupplyO2Percent;
  final double scrVo2;
  final List<TissueCompartment>? startCompartments;
  final double startOtu;

  const _ProfileAnalysisInput({
    required this.gfLow,
    required this.gfHigh,
    required this.ppO2WarningThreshold,
    required this.ppO2CriticalThreshold,
    required this.cnsWarningThreshold,
    required this.ascentRateWarning,
    required this.ascentRateCritical,
    required this.lastStopDepth,
    required this.diveId,
    required this.depths,
    required this.timestamps,
    required this.o2Fraction,
    required this.heFraction,
    required this.startCns,
    this.pressures,
    this.diveMode = DiveMode.oc,
    this.setpointHigh,
    this.setpointLow,
    this.scrInjectionRate,
    this.scrSupplyO2Percent,
    this.scrVo2 = ScrCalculator.defaultVo2,
    this.startCompartments,
    this.startOtu = 0.0,
  });
}

/// Top-level function for [compute] -- runs Buhlmann profile analysis on a
/// background isolate so the UI thread stays responsive.
ProfileAnalysis _runProfileAnalysis(_ProfileAnalysisInput input) {
  final service = ProfileAnalysisService(
    gfLow: input.gfLow,
    gfHigh: input.gfHigh,
    ppO2WarningThreshold: input.ppO2WarningThreshold,
    ppO2CriticalThreshold: input.ppO2CriticalThreshold,
    cnsWarningThreshold: input.cnsWarningThreshold,
    ascentRateWarning: input.ascentRateWarning,
    ascentRateCritical: input.ascentRateCritical,
    lastStopDepth: input.lastStopDepth,
  );
  return service.analyze(
    diveId: input.diveId,
    depths: input.depths,
    timestamps: input.timestamps,
    o2Fraction: input.o2Fraction,
    heFraction: input.heFraction,
    startCns: input.startCns,
    pressures: input.pressures,
    diveMode: input.diveMode,
    setpointHigh: input.setpointHigh,
    setpointLow: input.setpointLow,
    scrInjectionRate: input.scrInjectionRate,
    scrSupplyO2Percent: input.scrSupplyO2Percent,
    scrVo2: input.scrVo2,
    startCompartments: input.startCompartments,
    startOtu: input.startOtu,
  );
}

/// Provider for profile analysis of a specific dive.
///
/// Recursively computes residual CNS from previous dives: looks up the
/// previous dive via [profileAnalysisProvider] (different dive ID), applies
/// surface-interval decay, and uses the result as startCns. The chain
/// terminates when there is no previous dive or the surface interval >= 24h.
final profileAnalysisProvider = FutureProvider.family<ProfileAnalysis?, String>((
  ref,
  diveId,
) async {
  try {
    // Get the dive with profile data
    final diveAsync = ref.watch(diveProvider(diveId));

    // Await the dive data
    final dive = await diveAsync.when(
      data: (d) async => d,
      loading: () async => null,
      error: (e, st) async {
        _log.error(
          'Error loading dive for analysis: $diveId',
          error: e,
          stackTrace: st,
        );
        return null;
      },
    );

    if (dive == null || dive.profile.isEmpty) {
      _log.debug('No profile data for dive $diveId');
      return null;
    }

    // Resolve GF values: use dive-specific if provided, else user settings
    final double gfLow;
    final double gfHigh;
    if (dive.gradientFactorLow != null && dive.gradientFactorHigh != null) {
      _log.debug(
        'Using dive-specific GF ${dive.gradientFactorLow}/'
        '${dive.gradientFactorHigh} for dive $diveId',
      );
      gfLow = (dive.gradientFactorLow! / 100.0).clamp(0.0, 1.0);
      gfHigh = (dive.gradientFactorHigh! / 100.0).clamp(0.0, 1.0);
    } else {
      gfLow = ref.watch(gfLowProvider) / 100.0;
      gfHigh = ref.watch(gfHighProvider) / 100.0;
    }

    // Extract profile data
    final depths = dive.profile.map((p) => p.depth).toList();
    final timestamps = dive.profile.map((p) => p.timestamp).toList();

    // Try to get per-tank pressure data first (works for single and multi-tank)
    List<double>? pressures;
    if (dive.tanks.isNotEmpty) {
      // Load per-tank pressure data from tank_pressure_profiles table
      final tankPressureRepo = ref.watch(tankPressureRepositoryProvider);
      final tankPressures = await tankPressureRepo.getTankPressuresForDive(
        diveId,
      );

      if (tankPressures.isNotEmpty) {
        _log.debug(
          'Loading multi-tank pressure data: ${tankPressures.length} tanks',
        );
        pressures = _combineMultiTankPressures(
          timestamps: timestamps,
          tankPressures: tankPressures,
          tanks: dive.tanks,
        );
      }
    }

    // Get gas mix from primary tank
    double o2Fraction = 0.21; // Default to air
    double heFraction = 0.0;
    if (dive.tanks.isNotEmpty) {
      final primaryTank = dive.tanks.first;
      o2Fraction = primaryTank.gasMix.o2 / 100.0;
      heFraction = primaryTank.gasMix.he / 100.0;
    }

    // Read per-metric source preferences from legend state.
    // Use select() to only watch the 4 data-source fields — toggling
    // visibility or expanding menu sections should NOT trigger a full
    // Buhlmann recalculation.
    final ndlSource = ref.watch(
      profileLegendProvider.select((s) => s.ndlSource),
    );
    final ceilingSource = ref.watch(
      profileLegendProvider.select((s) => s.ceilingSource),
    );
    final ttsSource = ref.watch(
      profileLegendProvider.select((s) => s.ttsSource),
    );
    final cnsSource = ref.watch(
      profileLegendProvider.select((s) => s.cnsSource),
    );

    final useComputerCns = cnsSource == MetricDataSource.computer;
    final computerCns = useComputerCns
        ? extractComputerCns(dive.profile)
        : null;

    // Compute residual CNS (skip if this dive has computer CNS data)
    final startCns = computerCns != null
        ? computerCns.cnsStart
        : await _computeResidualCns(ref, diveId);

    // Compute residual tissue state from previous dives (48h cutoff)
    final startCompartments = await _computeResidualTissueState(ref, diveId);

    // Compute cumulative OTU from earlier same-day dives
    final startOtu = await _computeResidualOtu(ref, diveId);

    // Run Buhlmann analysis on a background isolate to keep UI responsive
    _log.debug(
      'Analyzing profile for dive $diveId with ${depths.length} points, '
      'pressures: ${pressures?.length ?? 0}, mode: ${dive.diveMode}, '
      'startCns: ${startCns.toStringAsFixed(1)}',
    );
    final analysis = await compute(
      _runProfileAnalysis,
      _ProfileAnalysisInput(
        gfLow: gfLow,
        gfHigh: gfHigh,
        ppO2WarningThreshold: ref.watch(ppO2MaxWorkingProvider),
        ppO2CriticalThreshold: ref.watch(ppO2MaxDecoProvider),
        cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
        ascentRateWarning: ref.watch(ascentRateWarningProvider),
        ascentRateCritical: ref.watch(ascentRateCriticalProvider),
        lastStopDepth: ref.watch(lastStopDepthProvider),
        diveId: diveId,
        depths: depths,
        timestamps: timestamps,
        o2Fraction: o2Fraction,
        heFraction: heFraction,
        startCns: startCns,
        pressures: pressures,
        diveMode: dive.diveMode,
        setpointHigh: dive.setpointHigh,
        setpointLow: dive.setpointLow,
        scrInjectionRate: dive.scrInjectionRate,
        scrSupplyO2Percent: dive.diluentGas?.o2,
        scrVo2: dive.assumedVo2 ?? 1.3,
        startCompartments: startCompartments,
        startOtu: startOtu,
      ),
    );

    // Overlay computer-reported deco data where available
    final (overlaid, sourceInfo) = overlayComputerDecoData(
      analysis,
      dive.profile,
      ndlSource: ndlSource,
      ceilingSource: ceilingSource,
      ttsSource: ttsSource,
      cnsSource: cnsSource,
    );

    // Publish actual source info for legend badge display
    ref.read(metricSourceInfoProvider.notifier).state = sourceInfo;

    // Override o2Exposure with computer-reported CNS start/end
    final withCns = computerCns != null
        ? overlaid.copyWith(
            o2Exposure: overlaid.o2Exposure.copyWith(
              cnsStart: computerCns.cnsStart,
              cnsEnd: computerCns.cnsEnd,
            ),
          )
        : overlaid;

    // Merge DB events (dive computer events) with auto-detected events
    final dbEvents = await ref.watch(diveComputerEventsProvider(diveId).future);
    if (dbEvents.isEmpty) {
      return withCns;
    }
    final merged = mergeEvents(withCns.events, dbEvents);
    return withCns.copyWith(events: merged);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to analyze profile for dive: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
});

/// Computes residual CNS% from the previous dive using recursive lookback.
///
/// Fetches the previous dive, gets its full profile analysis (which itself
/// recursively accounts for even earlier dives), then applies exponential
/// decay based on the surface interval.
Future<double> _computeResidualCns(Ref ref, String diveId) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    final surfaceInterval = await repository.getSurfaceInterval(diveId);
    if (surfaceInterval == null || surfaceInterval.inHours >= 24) return 0.0;

    final previousDive = await repository.getPreviousDive(diveId);
    if (previousDive == null) return 0.0;

    // Short-circuit: if the legend's CNS source is set to computer and the
    // previous dive has computer CNS, use its last CNS sample directly
    // instead of full analysis.
    // Use select() to avoid invalidating on unrelated legend state changes.
    final cnsSource = ref.watch(
      profileLegendProvider.select((s) => s.cnsSource),
    );
    final useComputerCns = cnsSource == MetricDataSource.computer;
    if (useComputerCns) {
      final prevComputerCns = extractComputerCns(previousDive.profile);
      if (prevComputerCns != null) {
        return CnsTable.cnsAfterSurfaceInterval(
          prevComputerCns.cnsEnd,
          surfaceInterval.inMinutes,
        );
      }
    }

    // Read (not watch) the previous dive's full analysis to avoid cascading
    // Riverpod invalidations. Each profileAnalysisProvider independently
    // watches settings, so ref.read is sufficient for one-shot lookback.
    final previousAnalysis = await ref.read(
      profileAnalysisProvider(previousDive.id).future,
    );
    if (previousAnalysis == null) return 0.0;

    return CnsTable.cnsAfterSurfaceInterval(
      previousAnalysis.o2Exposure.cnsEnd,
      surfaceInterval.inMinutes,
    );
  } catch (e, stackTrace) {
    _log.error(
      'Failed to calculate residual CNS for: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return 0.0;
  }
}

/// Computes residual tissue compartment state from previous dives.
///
/// Mirrors the recursive CNS lookback pattern: fetches the previous dive's
/// full analysis (which recursively accounts for even earlier dives), extracts
/// end-of-dive compartments, then applies Schreiner off-gassing for the
/// surface interval.
///
/// Returns null if no previous dive exists or surface interval >= 48 hours
/// (tissues are effectively surface-saturated).
Future<List<TissueCompartment>?> _computeResidualTissueState(
  Ref ref,
  String diveId,
) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    final surfaceInterval = await repository.getSurfaceInterval(diveId);
    if (surfaceInterval == null || surfaceInterval.inHours >= 48) return null;

    final previousDive = await repository.getPreviousDive(diveId);
    if (previousDive == null) return null;

    // Read (not watch) the previous dive's full analysis to avoid cascading
    // Riverpod invalidations. Each profileAnalysisProvider independently
    // watches settings, so ref.read is sufficient for one-shot lookback.
    final previousAnalysis = await ref.read(
      profileAnalysisProvider(previousDive.id).future,
    );
    if (previousAnalysis == null || previousAnalysis.decoStatuses.isEmpty) {
      return null;
    }

    // Extract end-of-dive compartment state
    final endOfDiveCompartments =
        previousAnalysis.decoStatuses.last.compartments;

    // Apply Schreiner off-gassing for the surface interval
    final gfLow = ref.watch(gfLowDecimalProvider);
    final gfHigh = ref.watch(gfHighDecimalProvider);
    final algorithm = BuhlmannAlgorithm(gfLow: gfLow, gfHigh: gfHigh);
    algorithm.setCompartments(List.from(endOfDiveCompartments));
    algorithm.calculateSegment(
      depthMeters: 0,
      durationSeconds: surfaceInterval.inSeconds,
      fN2: airN2Fraction,
      fHe: 0.0,
    );

    return algorithm.compartments;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to calculate residual tissue state for: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
}

/// Computes cumulative OTU from earlier dives on the same calendar day.
///
/// Non-recursive: queries all dives on the same day, gets each dive's
/// profile analysis, and sums their per-dive OTU values.
///
/// Returns 0.0 if no earlier dives exist on the same day.
Future<double> _computeResidualOtu(Ref ref, String diveId) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    // Get current dive's date
    final currentDive = await repository.getDiveById(diveId);
    if (currentDive == null) return 0.0;

    final diveDate = currentDive.entryTime ?? currentDive.dateTime;
    final startOfDay = DateTime.utc(
      diveDate.year,
      diveDate.month,
      diveDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all dives on the same day
    final sameDayDives = await repository.getDivesInRange(startOfDay, endOfDay);

    // Sum OTU from dives that occurred BEFORE this one
    double totalOtu = 0.0;
    for (final dive in sameDayDives) {
      if (dive.id == diveId) continue;
      final diveTime = dive.entryTime ?? dive.dateTime;
      if (diveTime.isBefore(diveDate)) {
        // Read (not watch) to avoid cascading Riverpod invalidations.
        final analysis = await ref.read(
          profileAnalysisProvider(dive.id).future,
        );
        if (analysis != null) {
          totalOtu += analysis.o2Exposure.otu;
        }
      }
    }

    return totalOtu;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to calculate residual OTU for: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return 0.0;
  }
}

/// Provider that exposes the residual CNS% for a dive.
///
/// This is a convenience provider for synchronous consumers (like
/// [diveProfileAnalysisProvider]) that need the residual CNS value.
/// It derives the value from [profileAnalysisProvider]'s computed cnsStart.
final residualCnsProvider = FutureProvider.family<double, String>((
  ref,
  diveId,
) async {
  final analysis = await ref.watch(profileAnalysisProvider(diveId).future);
  return analysis?.o2Exposure.cnsStart ?? 0.0;
});

/// Provider that exposes the residual tissue compartment state for a dive.
///
/// Convenience provider for synchronous consumers (like
/// [diveProfileAnalysisProvider]) that need pre-loaded tissue compartments.
final residualTissueStateProvider =
    FutureProvider.family<List<TissueCompartment>?, String>((
      ref,
      diveId,
    ) async {
      return _computeResidualTissueState(ref, diveId);
    });

/// Provider that exposes the residual OTU from earlier same-day dives.
///
/// Convenience provider for synchronous consumers (like
/// [diveProfileAnalysisProvider]) that need cumulative OTU.
final residualOtuProvider = FutureProvider.family<double, String>((
  ref,
  diveId,
) async {
  return _computeResidualOtu(ref, diveId);
});

/// Weekly OTU rolling total for a given dive (7-day window ending on dive date).
///
/// Queries all dives in the 7 days leading up to (and including) the dive's
/// date, sums their OTU. Used by O2ToxicityCard for REPEX compliance display.
final weeklyOtuProvider = FutureProvider.family<double, String>((
  ref,
  diveId,
) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    final currentDive = await repository.getDiveById(diveId);
    if (currentDive == null) return 0.0;

    final diveDate = currentDive.entryTime ?? currentDive.dateTime;
    final endOfDay = DateTime.utc(
      diveDate.year,
      diveDate.month,
      diveDate.day,
    ).add(const Duration(days: 1));
    final sevenDaysAgo = endOfDay.subtract(const Duration(days: 7));

    final weekDives = await repository.getDivesInRange(sevenDaysAgo, endOfDay);

    double totalOtu = 0.0;
    for (final dive in weekDives) {
      // Read (not watch) to avoid cascading Riverpod invalidations.
      // Each profileAnalysisProvider independently watches settings,
      // so ref.read is sufficient for aggregation.
      final analysis = await ref.read(profileAnalysisProvider(dive.id).future);
      if (analysis != null) {
        totalOtu += analysis.o2Exposure.otu;
      }
    }

    return totalOtu;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to calculate weekly OTU for: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return 0.0;
  }
});

/// Provider for profile analysis using a Dive object directly.
///
/// Note: This synchronous provider always uses [MetricDataSource.computer]
/// for all four metrics (NDL, ceiling, TTS, CNS) when data is present.
/// It does not read per-metric source preferences from the legend state.
/// Use [profileAnalysisProvider] (by diveId) for preference-aware handling.
final diveProfileAnalysisProvider = Provider.family<ProfileAnalysis?, Dive>((
  ref,
  dive,
) {
  if (dive.profile.isEmpty) {
    return null;
  }

  try {
    // Use dive-specific GF if the dive computer provided them,
    // otherwise fall back to user settings
    if (dive.gradientFactorLow != null && dive.gradientFactorHigh != null) {
      _log.debug(
        'Using dive-specific GF ${dive.gradientFactorLow}/'
        '${dive.gradientFactorHigh} for dive ${dive.id}',
      );
    }
    final service = _resolveAnalysisService(
      ref,
      dive.gradientFactorLow,
      dive.gradientFactorHigh,
    );

    // Extract profile data
    final depths = dive.profile.map((p) => p.depth).toList();
    final timestamps = dive.profile.map((p) => p.timestamp).toList();

    // Get gas mix from primary tank
    double o2Fraction = 0.21; // Default to air
    double heFraction = 0.0;
    if (dive.tanks.isNotEmpty) {
      final primaryTank = dive.tanks.first;
      o2Fraction = primaryTank.gasMix.o2 / 100.0;
      heFraction = primaryTank.gasMix.he / 100.0;
    }

    // Get residual CNS from previous dive (0.0 while loading or if unavailable)
    final startCns = ref.watch(residualCnsProvider(dive.id)).valueOrNull ?? 0.0;

    // Get residual tissue state from previous dives (null while loading)
    final startCompartments = ref
        .watch(residualTissueStateProvider(dive.id))
        .valueOrNull;

    // Get cumulative OTU from earlier same-day dives (0.0 while loading)
    final startOtu = ref.watch(residualOtuProvider(dive.id)).valueOrNull ?? 0.0;

    final analysis = service.analyze(
      diveId: dive.id,
      depths: depths,
      timestamps: timestamps,
      o2Fraction: o2Fraction,
      heFraction: heFraction,
      startCns: startCns,
      startCompartments: startCompartments,
      startOtu: startOtu,
      // Pressure data requires async TankPressureRepository access;
      // this synchronous provider omits it. Use profileAnalysisProvider
      // (by diveId) for pressure-dependent analysis.
      pressures: null,
      // CCR/SCR parameters
      diveMode: dive.diveMode,
      setpointHigh: dive.setpointHigh,
      setpointLow: dive.setpointLow,
      scrInjectionRate: dive.scrInjectionRate,
      scrSupplyO2Percent: dive.diluentGas?.o2,
      scrVo2: dive.assumedVo2 ?? 1.3,
    );

    // Overlay computer-reported deco data where available
    final (overlaid, _) = overlayComputerDecoData(
      analysis,
      dive.profile,
      ndlSource: MetricDataSource.computer,
      ceilingSource: MetricDataSource.computer,
      ttsSource: MetricDataSource.computer,
      cnsSource: MetricDataSource.computer,
    );
    return overlaid;
  } catch (e, stackTrace) {
    _log.error(
      'Failed to analyze profile for dive: ${dive.id}',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
});

/// Provider for quick stats from profile analysis
final profileQuickStatsProvider = Provider.family<ProfileQuickStats?, String>((
  ref,
  diveId,
) {
  final analysisAsync = ref.watch(profileAnalysisProvider(diveId));

  return analysisAsync.when(
    data: (analysis) {
      if (analysis == null) return null;
      return ProfileQuickStats.fromAnalysis(analysis);
    },
    loading: () => null,
    error: (_, _) => null,
  );
});

/// Quick stats summary from profile analysis
class ProfileQuickStats {
  /// Maximum depth in meters
  final double maxDepth;

  /// Average depth in meters
  final double avgDepth;

  /// Dive duration in seconds
  final int durationSeconds;

  /// Maximum ascent rate in m/min
  final double maxAscentRate;

  /// Whether any ascent violations occurred
  final bool hadAscentViolations;

  /// CNS% at end of dive
  final double cnsEnd;

  /// Whether CNS warning triggered
  final bool cnsWarning;

  /// Minimum NDL during dive (seconds, -1 if went into deco)
  final int minNdl;

  /// Whether dive went into deco obligation
  final bool hadDecoObligation;

  /// Maximum ppO2 during dive
  final double maxPpO2;

  /// Number of events detected
  final int eventCount;

  /// Number of warning/alert events
  final int warningCount;

  const ProfileQuickStats({
    required this.maxDepth,
    required this.avgDepth,
    required this.durationSeconds,
    required this.maxAscentRate,
    required this.hadAscentViolations,
    required this.cnsEnd,
    required this.cnsWarning,
    required this.minNdl,
    required this.hadDecoObligation,
    required this.maxPpO2,
    required this.eventCount,
    required this.warningCount,
  });

  factory ProfileQuickStats.fromAnalysis(ProfileAnalysis analysis) {
    return ProfileQuickStats(
      maxDepth: analysis.maxDepth,
      avgDepth: analysis.averageDepth,
      durationSeconds: analysis.durationSeconds,
      maxAscentRate: analysis.ascentRateStats.maxAscentRate,
      hadAscentViolations: analysis.hadAscentViolations,
      cnsEnd: analysis.o2Exposure.cnsEnd,
      cnsWarning: analysis.o2Exposure.cnsWarning,
      minNdl: analysis.ndlCurve.isEmpty
          ? -1
          : analysis.ndlCurve.reduce((a, b) => a < b ? a : b),
      hadDecoObligation: analysis.hadDecoObligation,
      maxPpO2: analysis.o2Exposure.maxPpO2,
      eventCount: analysis.events.length,
      warningCount: analysis.warningEvents.length + analysis.alertEvents.length,
    );
  }

  /// Format duration as MM:SS or HH:MM:SS
  String get durationFormatted {
    final hours = durationSeconds ~/ 3600;
    final minutes = (durationSeconds % 3600) ~/ 60;
    final seconds = durationSeconds % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// Format min NDL as MM:SS or "DECO"
  String get minNdlFormatted {
    if (minNdl < 0) return 'DECO';
    if (minNdl > 99 * 60) return '>99 min';
    final minutes = minNdl ~/ 60;
    return '$minutes min';
  }
}
