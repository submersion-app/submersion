import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/profile_event.dart';
import 'package:submersion/features/dive_log/domain/services/profile_event_mapper.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_computer_providers.dart';
import 'package:submersion/features/dive_log/presentation/providers/dive_providers.dart';

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
/// When profile points contain computer-reported values for NDL, ceiling,
/// TTS, or CNS, those values take priority over the Buhlmann-calculated
/// values. Points without computer data fall back to the calculated values.
///
/// Returns the original [analysis] unchanged if no computer data is present.
ProfileAnalysis overlayComputerDecoData(
  ProfileAnalysis analysis,
  List<DiveProfilePoint> profile,
) {
  final hasComputerNdl = profile.any((p) => p.ndl != null);
  final hasComputerCeiling = profile.any((p) => p.ceiling != null);
  final hasComputerTts = profile.any((p) => p.tts != null);
  final hasComputerCns = profile.any((p) => p.cns != null);

  if (!hasComputerNdl &&
      !hasComputerCeiling &&
      !hasComputerTts &&
      !hasComputerCns) {
    return analysis;
  }

  return analysis.copyWith(
    ndlCurve: hasComputerNdl
        ? List<int>.generate(
            profile.length,
            (i) =>
                profile[i].ndl ??
                (i < analysis.ndlCurve.length ? analysis.ndlCurve[i] : 0),
          )
        : null,
    ceilingCurve: hasComputerCeiling
        ? List<double>.generate(
            profile.length,
            (i) =>
                profile[i].ceiling ??
                (i < analysis.ceilingCurve.length
                    ? analysis.ceilingCurve[i]
                    : 0.0),
          )
        : null,
    ttsCurve: hasComputerTts
        ? List<int>.generate(
            profile.length,
            (i) =>
                profile[i].tts ??
                (analysis.ttsCurve != null && i < analysis.ttsCurve!.length
                    ? analysis.ttsCurve![i]
                    : 0),
          )
        : null,
    cnsCurve: hasComputerCns
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

/// Provider for profile analysis of a specific dive.
///
/// Recursively computes residual CNS from previous dives: looks up the
/// previous dive via [profileAnalysisProvider] (different dive ID), applies
/// surface-interval decay, and uses the result as startCns. The chain
/// terminates when there is no previous dive or the surface interval >= 24h.
final profileAnalysisProvider = FutureProvider.family<ProfileAnalysis?, String>(
  (ref, diveId) async {
    try {
      // Get the dive with profile data
      final diveAsync = ref.watch(diveProvider(diveId));

      // Await the dive data
      final dive = await diveAsync.when(
        data: (d) async => d,
        loading: () async => null,
        error: (e, st) async {
          _log.error('Error loading dive for analysis: $diveId', e, st);
          return null;
        },
      );

      if (dive == null || dive.profile.isEmpty) {
        _log.debug('No profile data for dive $diveId');
        return null;
      }

      // Use dive-specific GF if the dive computer provided them,
      // otherwise fall back to user settings
      if (dive.gradientFactorLow != null && dive.gradientFactorHigh != null) {
        _log.debug(
          'Using dive-specific GF ${dive.gradientFactorLow}/'
          '${dive.gradientFactorHigh} for dive $diveId',
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

      // Try to get multi-tank pressure data first
      List<double>? pressures;
      if (dive.tanks.length > 1) {
        // Load per-tank pressure data for multi-tank dives
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

      // Fall back to single pressure from profile if no multi-tank data
      if (pressures == null || pressures.length != depths.length) {
        final singlePressures = dive.profile
            .where((p) => p.pressure != null)
            .map((p) => p.pressure!)
            .toList();
        if (singlePressures.length == depths.length) {
          pressures = singlePressures;
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

      // Compute residual CNS from the previous dive (recursive multi-level)
      final startCns = await _computeResidualCns(ref, diveId);

      // Analyze the profile
      _log.debug(
        'Analyzing profile for dive $diveId with ${depths.length} points, '
        'pressures: ${pressures?.length ?? 0}, mode: ${dive.diveMode}, '
        'startCns: ${startCns.toStringAsFixed(1)}',
      );
      final analysis = service.analyze(
        diveId: diveId,
        depths: depths,
        timestamps: timestamps,
        o2Fraction: o2Fraction,
        heFraction: heFraction,
        startCns: startCns,
        pressures: pressures,
        // CCR/SCR parameters
        diveMode: dive.diveMode,
        setpointHigh: dive.setpointHigh,
        setpointLow: dive.setpointLow,
        scrInjectionRate: dive.scrInjectionRate,
        scrSupplyO2Percent:
            dive.diluentGas?.o2, // For SCR, diluent is the supply gas
        scrVo2: dive.assumedVo2 ?? 1.3,
      );

      // Overlay computer-reported deco data where available
      final overlaid = overlayComputerDecoData(analysis, dive.profile);

      // Merge DB events (dive computer events) with auto-detected events
      final dbEvents = await ref.watch(
        diveComputerEventsProvider(diveId).future,
      );
      if (dbEvents.isEmpty) {
        return overlaid;
      }
      final merged = mergeEvents(overlaid.events, dbEvents);
      return overlaid.copyWith(events: merged);
    } catch (e, stackTrace) {
      _log.error('Failed to analyze profile for dive: $diveId', e, stackTrace);
      return null;
    }
  },
);

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

    // Recursively get the previous dive's full analysis (including its own
    // residual CNS from even earlier dives).
    final previousAnalysis = await ref.watch(
      profileAnalysisProvider(previousDive.id).future,
    );
    if (previousAnalysis == null) return 0.0;

    return CnsTable.cnsAfterSurfaceInterval(
      previousAnalysis.o2Exposure.cnsEnd,
      surfaceInterval.inMinutes,
    );
  } catch (e, stackTrace) {
    _log.error('Failed to calculate residual CNS for: $diveId', e, stackTrace);
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

/// Provider for profile analysis using a Dive object directly.
///
/// Note: This synchronous provider does NOT merge DB events (dive computer
/// imported events). Use [profileAnalysisProvider] (by diveId) for the full
/// event set including dive-computer-imported events.
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
    final pressures = dive.profile
        .where((p) => p.pressure != null)
        .map((p) => p.pressure!)
        .toList();

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

    final analysis = service.analyze(
      diveId: dive.id,
      depths: depths,
      timestamps: timestamps,
      o2Fraction: o2Fraction,
      heFraction: heFraction,
      startCns: startCns,
      pressures: pressures.length == depths.length ? pressures : null,
      // CCR/SCR parameters
      diveMode: dive.diveMode,
      setpointHigh: dive.setpointHigh,
      setpointLow: dive.setpointLow,
      scrInjectionRate: dive.scrInjectionRate,
      scrSupplyO2Percent: dive.diluentGas?.o2,
      scrVo2: dive.assumedVo2 ?? 1.3,
    );

    // Overlay computer-reported deco data where available
    return overlayComputerDecoData(analysis, dive.profile);
  } catch (e, stackTrace) {
    _log.error('Failed to analyze profile for dive: ${dive.id}', e, stackTrace);
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
