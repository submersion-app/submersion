import 'package:submersion/core/providers/provider.dart';

import '../../../../core/services/logger_service.dart';
import '../../../settings/presentation/providers/settings_providers.dart';
import '../../data/services/profile_analysis_service.dart';
import '../../domain/entities/dive.dart';
import 'dive_providers.dart';

/// Placeholder class for logger
class _ProfileAnalysisProvider {}

final _log = LoggerService.forClass(_ProfileAnalysisProvider);

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

/// Provider for profile analysis of a specific dive
final profileAnalysisProvider =
    FutureProvider.family<ProfileAnalysis?, String>((ref, diveId) async {
  try {
    // Get the dive with profile data
    final diveAsync = ref.watch(diveProvider(diveId));

    return diveAsync.when(
      data: (dive) {
        if (dive == null || dive.profile.isEmpty) {
          _log.debug('No profile data for dive $diveId');
          return null;
        }

        final service = ref.watch(profileAnalysisServiceProvider);

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

        // Analyze the profile
        _log.debug(
          'Analyzing profile for dive $diveId with ${depths.length} points',
        );
        return service.analyze(
          diveId: diveId,
          depths: depths,
          timestamps: timestamps,
          o2Fraction: o2Fraction,
          heFraction: heFraction,
          startCns: 0.0, // TODO: Calculate from previous dive
          pressures: pressures.length == depths.length ? pressures : null,
        );
      },
      loading: () => null,
      error: (e, st) {
        _log.error('Error loading dive for analysis: $diveId', e, st);
        return null;
      },
    );
  } catch (e, stackTrace) {
    _log.error('Failed to analyze profile for dive: $diveId', e, stackTrace);
    return null;
  }
});

/// Provider for profile analysis using a Dive object directly
final diveProfileAnalysisProvider =
    Provider.family<ProfileAnalysis?, Dive>((ref, dive) {
  if (dive.profile.isEmpty) {
    return null;
  }

  try {
    final service = ref.watch(profileAnalysisServiceProvider);

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

    return service.analyze(
      diveId: dive.id,
      depths: depths,
      timestamps: timestamps,
      o2Fraction: o2Fraction,
      heFraction: heFraction,
      startCns: 0.0,
      pressures: pressures.length == depths.length ? pressures : null,
    );
  } catch (e, stackTrace) {
    _log.error('Failed to analyze profile for dive: ${dive.id}', e, stackTrace);
    return null;
  }
});

/// Provider for quick stats from profile analysis
final profileQuickStatsProvider =
    Provider.family<ProfileQuickStats?, String>((ref, diveId) {
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
