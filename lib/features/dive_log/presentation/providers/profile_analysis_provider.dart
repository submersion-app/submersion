import 'package:flutter/foundation.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/constants/profile_metrics.dart';
import 'package:submersion/core/deco/ascent/ascent_gas_plan.dart';
import 'package:submersion/core/deco/buhlmann_algorithm.dart';
import 'package:submersion/core/deco/constants/buhlmann_coefficients.dart';
import 'package:submersion/core/deco/o2_toxicity_calculator.dart';
import 'package:submersion/core/deco/entities/dive_environment.dart';
import 'package:submersion/core/deco/entities/o2_exposure.dart';
import 'package:submersion/core/deco/entities/profile_gas_segment.dart';
import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/core/deco/scr_calculator.dart';
import 'package:submersion/core/providers/provider.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/settings/presentation/providers/settings_providers.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/entities/gas_switch.dart';
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

/// Combines pressure data from one or more tanks into a single pressure series.
///
/// Aligns each tank's pressure readings to [timestamps] (interpolating between
/// samples) to track total gas consumption across all tanks.
///
/// Tank volume is used only to weight multiple tanks against each other. When
/// no tank has a configured volume -- common for dives imported from a dive
/// computer such as a Shearwater, which logs tank pressure but not cylinder
/// size -- the tanks are weighted equally so a SAC curve (bar/min) can still be
/// produced; for a single tank this yields its raw pressure series.
///
/// Returns a list of combined pressures aligned with [timestamps], or null if
/// no tank pressure data is available.
@visibleForTesting
List<double>? combineMultiTankPressures({
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

  // Volume is only needed to weight multiple tanks against each other. When no
  // tank has a configured volume -- common for dives imported from a dive
  // computer such as a Shearwater, which logs tank pressure but not cylinder
  // size -- fall back to equal weighting so the SAC curve (bar/min) can still
  // be produced. For a single tank this yields its raw pressure series.
  if (tankVolumes.isEmpty) {
    for (final tank in tanks) {
      tankVolumes[tank.id] = 1.0;
    }
  }

  // For each timestamp, calculate total gas consumption (in liters at surface)
  // from all tanks with pressure data
  final combinedPressures = <double>[];

  // Per-tank cursor; timestamps and each tank's points are ascending, so the
  // cursor only advances across the whole pass (O(N + sum(points)) total,
  // replacing the previous per-timestamp restart-from-zero O(N^2) scan).
  final cursors = <String, int>{
    for (final entry in tankPressures.entries) entry.key: 0,
  };

  for (int i = 0; i < timestamps.length; i++) {
    final targetTime = timestamps[i];
    double totalGasLiters = 0;
    double totalVolume = 0;

    for (final entry in tankPressures.entries) {
      final tankId = entry.key;
      final pressurePoints = entry.value;
      if (pressurePoints.isEmpty) continue;

      // The pressure series is already scoped to this dive. A tank id that no
      // longer matches a current tank -- e.g. a re-import or reparse re-keyed
      // the dive's tanks with fresh UUIDs (issue #276) -- must not discard the
      // data; fall back to a unit volume so the orphaned series still
      // contributes (a lone re-keyed tank then yields its raw pressure series)
      // instead of the SAC curve silently disappearing ("un-keyed").
      final tankVolume = tankVolumes[tankId] ?? 1.0;

      // Advance this tank's cursor to the first point at or after targetTime.
      // Timestamps are ascending, so the cursor never rewinds.
      var j = cursors[tankId]!;
      while (j < pressurePoints.length &&
          pressurePoints[j].timestamp < targetTime) {
        j++;
      }
      cursors[tankId] = j;

      final double pressure;
      if (j < pressurePoints.length &&
          pressurePoints[j].timestamp == targetTime) {
        pressure = pressurePoints[j].pressure;
      } else if (j > 0 && j < pressurePoints.length) {
        // Interpolate between j-1 and j.
        final p1 = pressurePoints[j - 1];
        final p2 = pressurePoints[j];
        final ratio =
            (targetTime - p1.timestamp) / (p2.timestamp - p1.timestamp);
        pressure = p1.pressure + (p2.pressure - p1.pressure) * ratio;
      } else if (j < pressurePoints.length) {
        // targetTime is before the first point (j == 0).
        pressure = pressurePoints[j].pressure;
      } else {
        // targetTime is after all points.
        pressure = pressurePoints.last.pressure;
      }

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

/// Builds a time-ordered gas schedule for decompression analysis.
///
/// The schedule always starts at timestamp 0 using the primary tank gas when
/// available, otherwise air. Gas switches then replace the active gas from
/// their timestamp onward.
DiveTank? _selectOcPrimaryTank(Dive dive) {
  if (dive.tanks.isEmpty) return null;
  return dive.tanks.firstWhere(
    (t) => t.role == TankRole.backGas,
    orElse: () => dive.tanks.first,
  );
}

List<ProfileGasSegment> buildProfileGasSegments(
  Dive dive,
  List<GasSwitchWithTank> gasSwitches,
) {
  final primaryMix = _selectOcPrimaryTank(dive)?.gasMix ?? const GasMix();

  final segments = <ProfileGasSegment>[
    ProfileGasSegment(
      startTimestamp: 0,
      fN2: primaryMix.isAir
          ? airN2Fraction
          : (100.0 - primaryMix.o2 - primaryMix.he) / 100.0,
      fHe: primaryMix.he / 100.0,
    ),
  ];

  final sortedSwitches = List<GasSwitchWithTank>.from(gasSwitches)
    ..sort((a, b) {
      final timestampCompare = a.timestamp.compareTo(b.timestamp);
      if (timestampCompare != 0) {
        return timestampCompare;
      }

      return a.id.compareTo(b.id);
    });

  for (final gasSwitch in sortedSwitches) {
    final nextSegment = ProfileGasSegment(
      startTimestamp: gasSwitch.timestamp,
      fN2: gasSwitch.isAir ? airN2Fraction : gasSwitch.n2Fraction,
      fHe: gasSwitch.heFraction,
    );

    if (segments.last.startTimestamp == nextSegment.startTimestamp) {
      _log.warning(
        'Multiple gas switches share timestamp ${nextSegment.startTimestamp}; '
        'using switch ${gasSwitch.id} after id-based tie-breaker',
      );
      segments[segments.length - 1] = nextSegment;
      continue;
    }

    segments.add(nextSegment);
  }

  return segments;
}

/// Maps the dive's recorded cylinders to the gas set the ideal ascent may use.
///
/// [maxPpO2] is the diver's ppO2MaxDeco ceiling; each gas's MOD is derived from
/// it via [O2ToxicityCalculator.calculateMod]. No gases are invented -- only
/// cylinders recorded on the dive. [gasSet] filters per the diver setting; the
/// back gas is always retained as the ascent floor.
@visibleForTesting
List<AvailableGas> buildAvailableGases(
  Dive dive, {
  required double maxPpO2,
  required AscentGasSet gasSet,
}) {
  bool keep(DiveTank t) {
    if (gasSet == AscentGasSet.allCarried) return true;
    return t.role == TankRole.backGas ||
        t.role == TankRole.deco ||
        t.role == TankRole.stage ||
        t.role == TankRole.bailout;
  }

  final gases = <AvailableGas>[];
  final seen = <String>{};
  for (final tank in dive.tanks.where(keep)) {
    final fO2 = tank.gasMix.o2 / 100.0;
    final fHe = tank.gasMix.he / 100.0;
    final fN2 = (1.0 - fO2 - fHe).clamp(0.0, 1.0);
    // Deduplicate identical mixes so the optimizer's tie-break stays stable.
    final key = '${fO2.toStringAsFixed(4)}_${fHe.toStringAsFixed(4)}';
    if (!seen.add(key)) continue;
    gases.add(
      AvailableGas(
        fN2: fN2,
        fHe: fHe,
        maxPpO2Mod: O2ToxicityCalculator.calculateMod(fO2, maxPpO2: maxPpO2),
      ),
    );
  }
  return gases;
}

/// Creates a ProfileAnalysisService using dive-specific GF and environment
/// (altitude, water type) when available, falling back to user settings.
ProfileAnalysisService _resolveAnalysisService(
  Ref ref,
  int? gradientFactorLow,
  int? gradientFactorHigh, {
  DiveEnvironment environment = DiveEnvironment.standard,
}) {
  if (gradientFactorLow == null &&
      gradientFactorHigh == null &&
      environment == DiveEnvironment.standard) {
    return ref.watch(profileAnalysisServiceProvider);
  }
  final gfLow = gradientFactorLow != null && gradientFactorHigh != null
      ? (gradientFactorLow / 100.0).clamp(0.0, 1.0)
      : ref.watch(gfLowProvider) / 100.0;
  final gfHigh = gradientFactorLow != null && gradientFactorHigh != null
      ? (gradientFactorHigh / 100.0).clamp(0.0, 1.0)
      : ref.watch(gfHighProvider) / 100.0;
  return ProfileAnalysisService(
    gfLow: gfLow,
    gfHigh: gfHigh,
    ppO2WarningThreshold: ref.watch(ppO2MaxWorkingProvider),
    ppO2CriticalThreshold: ref.watch(ppO2MaxDecoProvider),
    cnsWarningThreshold: ref.watch(cnsWarningThresholdProvider),
    ascentRateWarning: ref.watch(ascentRateWarningProvider),
    ascentRateCritical: ref.watch(ascentRateCriticalProvider),
    lastStopDepth: ref.watch(lastStopDepthProvider),
    environment: environment,
  );
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
  RebreatherPpO2? rebreatherPpO2,
}) {
  final hasComputerNdl = profile.any((p) => p.ndl != null);
  final hasComputerCeiling = profile.any((p) => p.ceiling != null);
  // TTS=0 is a sentinel from dive computers that don't track TTS;
  // treat it as unavailable so we fall back to calculated values.
  final hasComputerTts = profile.any((p) => p.tts != null && p.tts! > 0);
  final hasComputerCns = profile.any((p) => p.cns != null);

  final useNdl = ndlSource == MetricDataSource.computer && hasComputerNdl;
  final useCeiling =
      ceilingSource == MetricDataSource.computer && hasComputerCeiling;
  final useTts = ttsSource == MetricDataSource.computer && hasComputerTts;
  final useCns = cnsSource == MetricDataSource.computer && hasComputerCns;

  // ---- ppO2 / O2 cell overlay (CCR/SCR) ----
  // For rebreather dives the displayed ppO2 must come from sensor data or the
  // setpoint, never the OC depth x FO2 fallback. The same resolved curve is fed
  // into the analysis (see [resolveRebreatherPpO2]) so the CNS/OTU numbers match
  // the displayed ppO2. Callers that already resolved it pass it in to avoid a
  // second pass over the profile; otherwise resolve it here.
  final resolved = rebreatherPpO2 ?? resolveRebreatherPpO2(profile);
  final resolvedPpO2 = resolved?.curve;
  final o2SensorCurves = resolved?.sensorCurves;
  final ppO2FromSensorAverage = resolved?.fromSensorAverage ?? false;

  // Report actual source used (fallback to calculated if no data)
  final sourceInfo = (
    ndlActual: useNdl ? MetricDataSource.computer : MetricDataSource.calculated,
    ceilingActual: useCeiling
        ? MetricDataSource.computer
        : MetricDataSource.calculated,
    ttsActual: useTts ? MetricDataSource.computer : MetricDataSource.calculated,
    cnsActual: useCns ? MetricDataSource.computer : MetricDataSource.calculated,
  );

  if (!useNdl && !useCeiling && !useTts && !useCns && resolvedPpO2 == null) {
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
            if (computerTts != null) return computerTts;
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
    // ppO2 from sensor/setpoint (null keeps the calculated curve).
    ppO2Curve: resolvedPpO2,
    o2SensorCurves: o2SensorCurves,
    ppO2FromSensorAverage: resolvedPpO2 != null ? ppO2FromSensorAverage : null,
  );

  return (overlaid, sourceInfo);
}

// Top-level cell accessors so they can form a `const` list of tear-offs.
double? _o2Sensor1(DiveProfilePoint p) => p.o2Sensor1;
double? _o2Sensor2(DiveProfilePoint p) => p.o2Sensor2;
double? _o2Sensor3(DiveProfilePoint p) => p.o2Sensor3;
double? _o2Sensor4(DiveProfilePoint p) => p.o2Sensor4;
double? _o2Sensor5(DiveProfilePoint p) => p.o2Sensor5;
double? _o2Sensor6(DiveProfilePoint p) => p.o2Sensor6;

const _cellAccessors = <double? Function(DiveProfilePoint)>[
  _o2Sensor1,
  _o2Sensor2,
  _o2Sensor3,
  _o2Sensor4,
  _o2Sensor5,
  _o2Sensor6,
];

double? _cellAverage(DiveProfilePoint p) {
  var sum = 0.0;
  var count = 0;
  for (final accessor in _cellAccessors) {
    final value = accessor(p);
    if (value != null) {
      sum += value;
      count++;
    }
  }
  return count == 0 ? null : sum / count;
}

/// Resolved per-sample ppO2 for a rebreather dive.
typedef RebreatherPpO2 = ({
  /// ppO2 (bar) at each sample, continuous (last-known carried across gaps).
  List<double> curve,

  /// True when [curve] comes from averaging O2 cells (no computer-supplied
  /// ppO2 was available). Used to label the chart tooltip.
  bool fromSensorAverage,

  /// Each O2 cell exposed as its own per-sample curve for the tooltip, or null
  /// when the dive has no cell data.
  List<List<double?>>? sensorCurves,
});

/// Resolves the per-sample ppO2 curve for a rebreather dive from sensor/setpoint
/// data, returning null for profiles with no cells/ppO2/setpoint (e.g. OC).
///
/// This is the single source of truth for rebreather ppO2: it is used both to
/// display the ppO2 curve and to drive the CNS/OTU calculation, so the two never
/// disagree. ppO2 priority is computer ppO2 (dc_supplied) -> cell average ->
/// setpoint, never the OC depth x FO2 fallback (the CCR ppO2 source rule).
RebreatherPpO2? resolveRebreatherPpO2(List<DiveProfilePoint> profile) {
  final hasComputerPpO2 = profile.any((p) => p.ppO2 != null);
  final hasCells = profile.any((p) => _cellAverage(p) != null);
  final hasSetpoint = profile.any((p) => p.setpoint != null);
  final hasSensorData = hasComputerPpO2 || hasCells;
  final hasRebreatherPpO2 = hasSensorData || hasSetpoint;
  if (!hasRebreatherPpO2) return null;

  // Pick ONE source for the whole dive — sensor data when present, otherwise
  // the setpoint — and never mix them. Mixing makes the curve jump between the
  // measured value and the setpoint on samples where the cells are momentarily
  // absent. Within the chosen source, hold the last known value across gaps
  // (and back-fill leading gaps with the first reading) so the curve stays
  // continuous instead of dropping out.
  final raw = List<double?>.generate(profile.length, (i) {
    final p = profile[i];
    return hasSensorData ? (p.ppO2 ?? _cellAverage(p)) : p.setpoint;
  });
  final firstKnown = raw.firstWhere((v) => v != null, orElse: () => null);
  double? carry = firstKnown;
  final curve = List<double>.generate(profile.length, (i) {
    final value = raw[i];
    if (value != null) carry = value;
    return carry ?? 0.0;
  });

  // Expose each cell as its own per-sample curve, indexed by physical cell
  // position so the tooltip labels them correctly (curve index i == Sensor
  // i+1). Build curves up to the highest-numbered cell that has any reading;
  // any lower cell with no readings stays an all-null curve, which the chart
  // skips per-sample. This keeps labels right even when cells are absent or
  // non-contiguous (e.g. a failed/unreported cell).
  List<List<double?>>? sensorCurves;
  var highestCell = -1;
  for (var i = 0; i < _cellAccessors.length; i++) {
    if (profile.any((p) => _cellAccessors[i](p) != null)) highestCell = i;
  }
  if (highestCell >= 0) {
    sensorCurves = [
      for (var i = 0; i <= highestCell; i++)
        profile.map(_cellAccessors[i]).toList(),
    ];
  }

  return (
    curve: curve,
    // Tooltip labels the value as an average only when cells are the source
    // (no computer-supplied ppO2 was available).
    fromSensorAverage: hasSensorData && !hasComputerPpO2,
    sensorCurves: sensorCurves,
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
  final List<ProfileGasSegment>? gasSegments;
  final List<AvailableGas>? ascentGases; // OC only; null => FixedAscentGas
  final double ascentMaxPpO2;
  final List<double>? rebreatherPpO2Curve;
  final DiveEnvironment environment;

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
    this.gasSegments,
    this.ascentGases,
    this.ascentMaxPpO2 = 1.6,
    this.rebreatherPpO2Curve,
    this.environment = DiveEnvironment.standard,
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
    environment: input.environment,
  );
  final ascentGasPlan =
      input.ascentGases != null && input.ascentGases!.isNotEmpty
      ? OptimalOcAscentGas(
          gases: input.ascentGases!,
          maxPpO2: input.ascentMaxPpO2,
        )
      : null;
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
    gasSegments: input.gasSegments,
    ascentGasPlan: ascentGasPlan,
    rebreatherPpO2Curve: input.rebreatherPpO2Curve,
  );
}

/// Lean dive hydration for the analysis pipeline: dive-row scalars, tanks,
/// and the merged profile only -- no joined display entities (WS2, large-DB
/// performance). keepAlive family, so a residual-chain walk over a
/// repetitive dive week hydrates each prior dive once per session instead
/// of fully re-hydrating on every detail open. Self-invalidates on the
/// detail-table tick exactly like diveProvider, preserving the analysis
/// refresh behavior that previously arrived transitively through
/// diveProvider.
final analysisDiveProvider = FutureProvider.family<Dive?, String>((
  ref,
  diveId,
) async {
  final repository = ref.watch(diveRepositoryProvider);
  ref.invalidateSelfWhen(repository.watchDiveDetailChanges());
  return repository.getDiveForAnalysis(diveId);
});

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
    // Await the dive itself (not just its current AsyncValue snapshot). Reading
    // `analysisDiveProvider(id).future` suspends this provider until the dive
    // resolves, rather than mapping a momentary loading state to a resolved
    // null. The old `.when(loading: () => null)` form committed an
    // AsyncData(null) whenever the analysis built while the dive was still
    // loading -- which a concurrent evaluator (residual-CNS/tissue/OTU lookback
    // from another dive, or stats aggregation) reliably triggers, especially
    // for the heavier merged profile of a multi-computer dive. Riverpod then
    // retained that null and never recomputed until a detail-table write or an
    // app restart, blanking every analysis-derived overlay and the deco/tissue
    // panels in the meantime. Errors surface to the outer catch below.
    final dive = await ref.watch(analysisDiveProvider(diveId).future);

    if (dive == null || dive.profile.isEmpty) {
      _log.debug('No profile data for dive $diveId');
      return null;
    }

    return await computeAnalysisForProfile(ref, dive, dive.profile);
  } catch (e, stackTrace) {
    _log.error(
      'Failed to analyze profile for dive: $diveId',
      error: e,
      stackTrace: stackTrace,
    );
    return null;
  }
});

/// Runs the full analysis pipeline over [profile] samples of [dive].
///
/// Extracted from [profileAnalysisProvider] so per-source analysis
/// ([sourceProfileAnalysisProvider]) can run the identical pipeline over one
/// data source's own samples. [computerId] scopes tank data to the owning
/// computer: null keeps the legacy behavior (all tanks, used for
/// single-source dives); non-null restricts gas mix and tank pressures to
/// that computer's tanks plus unattributed (manually added) tanks, which
/// belong to the dive rather than to either computer.
///
/// Throws on failure; callers wrap with their own error handling.
Future<ProfileAnalysis?> computeAnalysisForProfile(
  Ref ref,
  Dive dive,
  List<DiveProfilePoint> profile, {
  String? computerId,
}) async {
  {
    final diveId = dive.id;
    final tanks = computerId == null
        ? dive.tanks
        : dive.tanks
              .where((t) => t.computerId == null || t.computerId == computerId)
              .toList();
    final repository = ref.watch(diveRepositoryProvider);
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
    final depths = profile.map((p) => p.depth).toList();
    final timestamps = profile.map((p) => p.timestamp).toList();

    // Try to get per-tank pressure data first (works for single and multi-tank)
    List<double>? pressures;
    if (tanks.isNotEmpty) {
      // Load per-tank pressure data from tank_pressure_profiles table
      final tankPressureRepo = ref.watch(tankPressureRepositoryProvider);
      final allTankPressures = await tankPressureRepo.getTankPressuresForDive(
        diveId,
      );
      // Scope pressure curves to the requested computer's tanks; null keeps
      // every tank (primary-source / legacy behavior).
      final tankIds = {for (final t in tanks) t.id};
      final tankPressures = computerId == null
          ? allTankPressures
          : <String, List<TankPressurePoint>>{
              for (final entry in allTankPressures.entries)
                if (tankIds.contains(entry.key)) entry.key: entry.value,
            };

      if (tankPressures.isNotEmpty) {
        _log.debug(
          'Loading multi-tank pressure data: ${tankPressures.length} tanks',
        );
        pressures = combineMultiTankPressures(
          timestamps: timestamps,
          tankPressures: tankPressures,
          tanks: tanks,
        );
      }
    }

    // Get gas mix from primary tank
    double o2Fraction = 0.21; // Default to air
    double heFraction = 0.0;
    if (tanks.isNotEmpty) {
      final primaryTank = tanks.first;
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
    final computerCns = useComputerCns ? extractComputerCns(profile) : null;

    // Compute residual CNS (skip if this dive has computer CNS data)
    final startCns = computerCns != null
        ? computerCns.cnsStart
        : await _computeResidualCns(ref, diveId);

    // Compute residual tissue state from previous dives (48h cutoff)
    final startCompartments = await _computeResidualTissueState(ref, diveId);

    // Compute cumulative OTU from earlier same-day dives
    final startOtu = await _computeResidualOtu(ref, diveId);

    final gasSegments = dive.diveMode == DiveMode.oc
        ? buildProfileGasSegments(
            dive,
            await repository.getGasSwitchesForDive(diveId),
          )
        : null;
    final ascentMaxPpO2 = ref.watch(ppO2MaxDecoProvider);
    final ascentGases = dive.diveMode == DiveMode.oc
        ? buildAvailableGases(
            dive,
            maxPpO2: ascentMaxPpO2,
            gasSet: ref.watch(ascentGasSetProvider),
          )
        : null;
    // Resolve rebreather loop ppO2 once and reuse it for both the analysis
    // (CNS/OTU) and the display overlay so the two always agree.
    final rebreatherPpO2 = dive.diveMode == DiveMode.oc
        ? null
        : resolveRebreatherPpO2(profile);
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
        gasSegments: gasSegments,
        ascentGases: ascentGases,
        environment: DiveEnvironment.forConditions(
          altitudeMeters: dive.altitude,
          waterType: dive.waterType,
          surfacePressureBar: dive.surfacePressure,
        ),
        ascentMaxPpO2: ascentMaxPpO2,
        rebreatherPpO2Curve: rebreatherPpO2?.curve,
      ),
    );

    // Overlay computer-reported deco data where available
    final (overlaid, sourceInfo) = overlayComputerDecoData(
      analysis,
      profile,
      ndlSource: ndlSource,
      ceilingSource: ceilingSource,
      ttsSource: ttsSource,
      cnsSource: cnsSource,
      rebreatherPpO2: rebreatherPpO2,
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
  }
}

/// Key for per-source analysis. sourceId null = the primary source.
typedef DiveSourceKey = ({String diveId, String? sourceId});

/// Analysis computed from one data source's own samples -- the exact
/// series the chart draws, index for index. On multi-source dives EVERY
/// source (the primary included) is computed from its own bucket:
/// `dive.profile` can be a merged superset of the primary's samples (e.g.
/// dives consolidated by older app versions flagged both computers'
/// rows primary), and index-pairing a merged-length analysis against the
/// primary's bucket stretches every chart curve. Single-source dives
/// delegate to [profileAnalysisProvider] so its cache and residual-CNS
/// recursion are shared.
final sourceProfileAnalysisProvider =
    FutureProvider.family<ProfileAnalysis?, DiveSourceKey>((ref, key) async {
      try {
        final sources = await ref.watch(
          diveDataSourcesProvider(key.diveId).future,
        );
        if (sources.length < 2) {
          return await ref.watch(profileAnalysisProvider(key.diveId).future);
        }
        final primaryId =
            sources.where((s) => s.isPrimary).map((s) => s.id).firstOrNull ??
            sources.first.id;
        final effectiveSourceId = key.sourceId ?? primaryId;
        final dive = await ref.watch(analysisDiveProvider(key.diveId).future);
        if (dive == null) return null;
        final profiles = await ref.watch(
          sourceProfilesProvider(key.diveId).future,
        );
        final sourceProfile = profiles[effectiveSourceId];
        if (sourceProfile == null) {
          // Bucket unavailable (still loading, or stale id): fall back to
          // the dive-level analysis rather than blanking the panels.
          return await ref.watch(profileAnalysisProvider(key.diveId).future);
        }
        if (sourceProfile.points.isEmpty) {
          return null;
        }
        return await computeAnalysisForProfile(
          ref,
          dive,
          sourceProfile.points,
          computerId: sourceProfile.computerId,
        );
      } catch (e, stackTrace) {
        _log.error(
          'Failed to analyze source ${key.sourceId} profile for dive: '
          '${key.diveId}',
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
    if (surfaceInterval == null || surfaceInterval.inHours >= 24) {
      return 0.0;
    }

    final previousDive = await repository.getPreviousDiveTimes(diveId);
    if (previousDive == null) return 0.0;

    // Short-circuit: if the legend's CNS source is set to computer and the
    // previous dive has computer CNS, use its last CNS sample directly
    // instead of full analysis. The profile is fetched only when this
    // branch is taken (times-only lookup otherwise).
    // Use select() to avoid invalidating on unrelated legend state changes.
    final cnsSource = ref.watch(
      profileLegendProvider.select((s) => s.cnsSource),
    );
    final useComputerCns = cnsSource == MetricDataSource.computer;
    if (useComputerCns) {
      final previousProfile = await repository.getMergedProfile(
        previousDive.id,
      );
      final prevComputerCns = extractComputerCns(previousProfile);
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
    if (surfaceInterval == null || surfaceInterval.inHours >= 48) {
      return null;
    }

    final previousDive = await repository.getPreviousDiveTimes(diveId);
    if (previousDive == null) {
      return null;
    }

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

    // Get current dive's date (times-only projection; WS2)
    final currentDive = await repository.getDiveTimes(diveId);
    if (currentDive == null) return 0.0;

    final diveDate = currentDive.entryTime ?? currentDive.dateTime;
    final startOfDay = DateTime.utc(
      diveDate.year,
      diveDate.month,
      diveDate.day,
    );
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Get all dives on the same day
    final sameDayDives = await repository.getDiveTimesInRange(
      startOfDay,
      endOfDay,
    );

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
/// Queries dives in the 7 days leading up to the dive's date and sums the OTU
/// of the current dive plus any dive that occurred at or before it. Dives
/// logged LATER than the current dive (e.g. later the same day) are excluded
/// so the displayed "Prior" never borrows OTU from the future (issue #407).
/// Used by O2ToxicityCard for REPEX compliance display.
final weeklyOtuProvider = FutureProvider.family<double, String>((
  ref,
  diveId,
) async {
  try {
    final repository = ref.watch(diveRepositoryProvider);

    final currentDive = await repository.getDiveTimes(diveId);
    if (currentDive == null) return 0.0;

    final diveDate = currentDive.entryTime ?? currentDive.dateTime;
    final endOfDay = DateTime.utc(
      diveDate.year,
      diveDate.month,
      diveDate.day,
    ).add(const Duration(days: 1));
    final sevenDaysAgo = endOfDay.subtract(const Duration(days: 7));

    final weekDives = await repository.getDiveTimesInRange(
      sevenDaysAgo,
      endOfDay,
    );

    double totalOtu = 0.0;
    for (final dive in weekDives) {
      // Count the current dive and any dive that occurred at or before it, but
      // skip dives logged LATER than the current dive. The query window spans
      // the current dive's whole calendar day, so without this guard a later
      // same-day dive would inflate the rolling total -- and the card derives
      // "Prior" as (weekly - thisDive), wrongly attributing the future dive's
      // OTU to this dive's prior exposure (issue #407). Mirrors the same-day
      // ordering discipline in [_computeResidualOtu].
      final diveTime = dive.entryTime ?? dive.dateTime;
      if (dive.id != diveId && diveTime.isAfter(diveDate)) continue;

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
      environment: DiveEnvironment.forConditions(
        altitudeMeters: dive.altitude,
        waterType: dive.waterType,
        surfacePressureBar: dive.surfacePressure,
      ),
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

    // Resolve rebreather loop ppO2 once and reuse it for both the analysis
    // (CNS/OTU) and the display overlay so the two always agree.
    final rebreatherPpO2 = dive.diveMode == DiveMode.oc
        ? null
        : resolveRebreatherPpO2(dive.profile);

    final ascentGases = dive.diveMode == DiveMode.oc
        ? buildAvailableGases(
            dive,
            maxPpO2: ref.watch(ppO2MaxDecoProvider),
            gasSet: ref.watch(ascentGasSetProvider),
          )
        : null;
    final ascentGasPlan = ascentGases != null && ascentGases.isNotEmpty
        ? OptimalOcAscentGas(
            gases: ascentGases,
            maxPpO2: ref.watch(ppO2MaxDecoProvider),
          )
        : null;

    final analysis = service.analyze(
      diveId: dive.id,
      depths: depths,
      timestamps: timestamps,
      o2Fraction: o2Fraction,
      heFraction: heFraction,
      startCns: startCns,
      startCompartments: startCompartments,
      startOtu: startOtu,
      pressures: null,
      // CCR/SCR parameters
      diveMode: dive.diveMode,
      setpointHigh: dive.setpointHigh,
      setpointLow: dive.setpointLow,
      scrInjectionRate: dive.scrInjectionRate,
      scrSupplyO2Percent: dive.diluentGas?.o2,
      scrVo2: dive.assumedVo2 ?? 1.3,
      ascentGasPlan: ascentGasPlan,
      rebreatherPpO2Curve: rebreatherPpO2?.curve,
    );

    // Overlay computer-reported deco data where available
    final (overlaid, _) = overlayComputerDecoData(
      analysis,
      dive.profile,
      ndlSource: MetricDataSource.computer,
      ceilingSource: MetricDataSource.computer,
      ttsSource: MetricDataSource.computer,
      cnsSource: MetricDataSource.computer,
      rebreatherPpO2: rebreatherPpO2,
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
