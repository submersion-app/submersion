import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';
import 'package:submersion/features/equipment/domain/entities/gear_provenance.dart';
import 'package:submersion/features/planner/domain/entities/mission/dpv_mission.dart';

/// Breathing mode of a saved dive plan.
///
/// [scr] is a constant-mass-flow semi-closed rebreather; [pscr] is a
/// passive-addition semi-closed rebreather (ventilation-coupled fresh gas).
enum PlanMode { oc, ccr, scr, pscr }

/// Gas turn-pressure rule for penetration planning (Phase 5).
///
/// [off] is an explicit "no turn-pressure tracking" choice, distinct from a
/// plan's [DivePlan.turnPressureRule] being unset (which follows the diver's
/// Settings default - issue #3552, where the default itself may resolve to
/// no tracking). Without [off], a plan would have no way to turn tracking
/// off for itself once the diver has set a non-null global default.
enum TurnPressureRule { off, allUsable, halves, thirds, custom }

/// The persisted dive plan aggregate (planner redesign Phase 2).
///
/// Inputs only — schedules, consumption, and issues are always recomputed by
/// the PlanEngine. Segments describe the user-authored bottom portion of the
/// dive; ascent and deco are computed.
class DivePlan extends Equatable {
  // Identity / meta
  final String id;
  final String name;
  final String notes;
  final String? siteId;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Mode + environment
  final PlanMode mode;
  final double? altitude;
  final WaterType? waterType;

  /// Custom salinity in ppt. When set, this wins over [waterType] for deco
  /// density - including when [waterType] is null. With both null the planner
  /// falls back to salt water, its default for a new plan.
  final double? salinityPpt;

  /// Planned start time; null = "now" at planning. Drives repetitive tissue
  /// init and overlap detection (v120).
  final DateTime? startDateTime;

  // Deco settings
  /// Null = use the diver's Settings default (issue #3552). Was
  /// snapshot-on-create until this follow-up reconsidered it: the diver's
  /// Settings default already existed ([gfLowProvider]/[gfHighProvider]),
  /// it just never reached a plan again once copied in at creation.
  final int? gfLow;
  final int? gfHigh;

  /// Descent rate in m/min. Null = use the diver's Settings default
  /// (issue #3552).
  final double? descentRate;

  /// Working ascent rate in m/min: leaving the bottom for the first stop.
  /// Null = use the diver's Settings default (issue #3552).
  final double? ascentRate;

  /// Ascent rate in m/min between intermediate (deeper than 9 m) stops -
  /// slower than [ascentRate], because a diver climbing the stop grid is not
  /// leaving the bottom. Null = use the diver's Settings default
  /// (issue #3552).
  final double? intermediateAscentRate;

  /// Ascent rate in m/min between shallow (9 m and above) stops. Null = use
  /// the diver's Settings default (issue #3552).
  final double? shallowAscentRate;

  /// Ascent rate in m/min from the last stop to the surface. The shallowest
  /// part of the ascent is where a depth change costs the most pressure
  /// change, so it is the slowest of the four. Null = use the diver's
  /// Settings default (issue #3552).
  final double? finalAscentRate;

  /// Null = use the diver's Settings default (issue #3552).
  final double? lastStopDepth;

  /// Null = use the diver's Settings default (issue #3552).
  final int? gasSwitchStopSeconds;

  /// Null and [airBreaksExplicitlyOff] false = use the diver's Settings
  /// default air-break policy (issue #3552; itself may be no policy). A
  /// value here is always an explicit custom policy, never the default.
  final AirBreakPolicy? airBreaks;

  /// True = no air breaks for this plan, regardless of the diver's Settings
  /// default. Distinct from [airBreaks] being unset, which follows that
  /// default instead of forcing it off (issue #3552).
  final bool airBreaksExplicitlyOff;

  /// Diver-authored minimum hold time in seconds, keyed by whole-metre stop
  /// depth. Passed straight through to [SchedulePolicy.minStopSecondsByDepth]
  /// so the engine's own stop-time computation honours it, rather than
  /// baking a fixed stop into the plan's segments.
  final Map<int, int> stopMinimums;

  // Gas planning
  /// Null = use the diver's Settings default (issue #3552).
  final double? sacBottom;

  /// Null = use the diver's Settings default (issue #3552; was "0.8x of
  /// bottom" before it had one - see [sacDecoEffective]).
  final double? sacDeco;

  /// Null = derive from [sacBottom] and the diver's Settings stressed-SAC
  /// factor (issue #3552) - see [sacStressedEffective].
  final double? sacStressed;

  /// Null = use the diver's Settings default (issue #3552).
  final double? reservePressure;

  // Gas options (Subsurface-style; issue-driven G-series follow-up).
  /// Multiplier on [sacStressedEffective]'s fallback for the minimum-gas /
  /// rock-bottom calculation, standing in for the app-wide
  /// `PlanEngineConfig.buddyFactor` default (2.0) once a plan sets it. Null
  /// = use the diver's Settings default (issue #3552).
  final double? sacFactor;

  /// Minutes spent at max depth at the stressed SAC before the ascent
  /// begins, in the minimum-gas calculation. Null = use the diver's
  /// Settings default (issue #3552; Subsurface default: 2).
  final int? problemSolvingMinutes;

  /// ppO2 ceiling for gas selection / MOD warnings during the working part
  /// of the dive. Null = use the app-wide setting.
  final double? ppO2Bottom;

  /// ppO2 ceiling for deco gas switch depths (MOD) and stop gas selection.
  /// Null = use the app-wide setting.
  final double? ppO2Deco;

  /// Equivalent narcotic depth target used when suggesting a best mix for a
  /// depth. Null = use the diver's Settings default (issue #3552;
  /// Subsurface default: 30 m, its UI shows 28 m).
  final double? bestMixEndMeters;

  /// Whether O2 counts as narcotic in END for this plan. Null = use the
  /// app-wide setting.
  final bool? o2Narcotic;

  // Repetitive context
  final Duration? surfaceInterval;
  final String? sourceDiveId;
  final String? linkedDiveId;

  // CCR config (Phase 4 UI; persisted now)
  final double? setpointLow;
  final double? setpointHigh;
  final double? setpointSwitchDepth;

  // Contingency config (Phase 5 UI; persisted now)
  /// Null = use the diver's Settings default (issue #3552).
  final double? deviationDepthDelta;

  /// Null = use the diver's Settings default (issue #3552).
  final int? deviationTimeMinutes;

  /// Null = use the diver's Settings default (issue #3552; itself may
  /// resolve to no rule). [TurnPressureRule.off] is the explicit "no
  /// tracking for this plan" choice, distinct from unset.
  final TurnPressureRule? turnPressureRule;
  final double? turnPressureFraction;

  // Content
  final List<PlanSegment> segments;
  final List<DiveTank> tanks;

  // Gear & Weights (v104): equipment attached to the plan plus the accepted
  // weight-prediction snapshot (placement keyed by WeightType.name -> kg).
  final List<String> equipmentIds;

  /// Where each id in [equipmentIds] came from (issue #1487): the assembly
  /// it was attached through and the set applied. An id with no entry is a
  /// top-level row added by hand.
  final List<GearProvenance> gearProvenance;
  final double? plannedWeightKg;
  final Map<String, double>? plannedWeightPlacement;

  /// The DPV mission layered on this plan, or null for a plan without one.
  /// When present, [segments] are generated from the mission's route and
  /// must be treated as a cache of it, never edited by hand.
  final DpvMission? mission;

  const DivePlan({
    required this.id,
    required this.name,
    this.notes = '',
    this.siteId,
    required this.createdAt,
    required this.updatedAt,
    this.mode = PlanMode.oc,
    this.altitude,
    this.waterType,
    this.salinityPpt,
    this.startDateTime,
    this.gfLow,
    this.gfHigh,
    this.descentRate,
    this.ascentRate,
    this.intermediateAscentRate,
    this.shallowAscentRate,
    this.finalAscentRate,
    this.lastStopDepth,
    this.gasSwitchStopSeconds,
    this.airBreaks,
    this.airBreaksExplicitlyOff = false,
    this.stopMinimums = const {},
    this.sacBottom,
    this.sacDeco,
    this.sacStressed,
    this.reservePressure,
    this.sacFactor,
    this.problemSolvingMinutes,
    this.ppO2Bottom,
    this.ppO2Deco,
    this.bestMixEndMeters,
    this.o2Narcotic,
    this.surfaceInterval,
    this.sourceDiveId,
    this.linkedDiveId,
    this.setpointLow,
    this.setpointHigh,
    this.setpointSwitchDepth,
    this.deviationDepthDelta,
    this.deviationTimeMinutes,
    this.turnPressureRule,
    this.turnPressureFraction,
    this.segments = const [],
    this.tanks = const [],
    this.equipmentIds = const [],
    this.gearProvenance = const [],
    this.plannedWeightKg,
    this.plannedWeightPlacement,
    this.mission,
  });

  /// Pure spec defaults (0.7 shallow, 1.3 below 10 m), the last resort for
  /// a caller with no access to the diver's CCR ppO2 Settings. An unset
  /// [setpointLow] / [setpointHigh] resolves through
  /// `PlanEngineConfig.setpointLowFor` / `setpointHighFor`, which carry the
  /// diver's Settings and default to these constants; there is deliberately
  /// no getter here that falls back to them directly, because one would
  /// skip the Settings (issue #2801).
  static const double specSetpointLow = 0.7;
  static const double specSetpointHigh = 1.3;
  double get effectiveSetpointSwitchDepth => setpointSwitchDepth ?? 10.0;

  /// Bottom SAC: explicit value, otherwise the 15 L/min spec default - the
  /// last resort for a caller with no diver Settings to hand (same reason
  /// as [specSetpointLow] above). A caller with a [PlanEngineConfig]
  /// resolved for this plan reads `config.sacBottom` instead, which already
  /// carries the diver's Settings default (issue #3552).
  double get sacBottomEffective => sacBottom ?? 15.0;

  /// Deco SAC: explicit value, otherwise the 15 L/min spec default - same
  /// last-resort caveat as [sacBottomEffective]; a config-aware caller
  /// reads `config.sacDeco` instead (issue #3552).
  double get sacDecoEffective => sacDeco ?? 15.0;

  /// Stressed (bailout/rock-bottom) SAC: explicit, otherwise 2.5x
  /// [sacBottomEffective] - same last-resort caveat; a config-aware caller
  /// reads `config.sacStressedFor(plan)` instead, which uses the diver's
  /// Settings stressed-SAC factor rather than the hardcoded 2.5 (issue
  /// #3552).
  double get sacStressedEffective => sacStressed ?? sacBottomEffective * 2.5;

  /// Deepest point across the user-authored segments (0 if none).
  ///
  /// Only targets need checking: every leg starts where the previous one
  /// finished, so a start depth is always some earlier segment's target.
  double get maxDepth {
    double deepest = 0;
    for (final segment in segments) {
      if (segment.targetDepth > deepest) deepest = segment.targetDepth;
    }
    return deepest;
  }

  DivePlan copyWith({
    String? id,
    String? name,
    String? notes,
    String? siteId,
    bool clearSiteId = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    PlanMode? mode,
    double? altitude,
    bool clearAltitude = false,
    WaterType? waterType,
    double? salinityPpt,
    DateTime? startDateTime,
    bool clearStartDateTime = false,
    bool clearWaterType = false,
    bool clearSalinityPpt = false,
    int? gfLow,
    bool clearGfLow = false,
    int? gfHigh,
    bool clearGfHigh = false,
    double? descentRate,
    bool clearDescentRate = false,
    double? ascentRate,
    bool clearAscentRate = false,
    double? intermediateAscentRate,
    bool clearIntermediateAscentRate = false,
    double? shallowAscentRate,
    bool clearShallowAscentRate = false,
    double? finalAscentRate,
    bool clearFinalAscentRate = false,
    double? lastStopDepth,
    bool clearLastStopDepth = false,
    int? gasSwitchStopSeconds,
    bool clearGasSwitchStopSeconds = false,
    AirBreakPolicy? airBreaks,
    bool clearAirBreaks = false,
    bool? airBreaksExplicitlyOff,
    Map<int, int>? stopMinimums,
    double? sacBottom,
    bool clearSacBottom = false,
    double? sacDeco,
    bool clearSacDeco = false,
    double? sacStressed,
    bool clearSacStressed = false,
    double? reservePressure,
    bool clearReservePressure = false,
    double? sacFactor,
    bool clearSacFactor = false,
    int? problemSolvingMinutes,
    bool clearProblemSolvingMinutes = false,
    double? ppO2Bottom,
    bool clearPpO2Bottom = false,
    double? ppO2Deco,
    bool clearPpO2Deco = false,
    double? bestMixEndMeters,
    bool clearBestMixEndMeters = false,
    bool? o2Narcotic,
    bool clearO2Narcotic = false,
    Duration? surfaceInterval,
    bool clearSurfaceInterval = false,
    String? sourceDiveId,
    bool clearSourceDiveId = false,
    String? linkedDiveId,
    bool clearLinkedDiveId = false,
    double? setpointLow,
    bool clearSetpointLow = false,
    double? setpointHigh,
    bool clearSetpointHigh = false,
    double? setpointSwitchDepth,
    bool clearSetpointSwitchDepth = false,
    double? deviationDepthDelta,
    bool clearDeviationDepthDelta = false,
    int? deviationTimeMinutes,
    bool clearDeviationTimeMinutes = false,
    TurnPressureRule? turnPressureRule,
    bool clearTurnPressureRule = false,
    double? turnPressureFraction,
    bool clearTurnPressureFraction = false,
    List<PlanSegment>? segments,
    List<DiveTank>? tanks,
    List<String>? equipmentIds,
    List<GearProvenance>? gearProvenance,
    double? plannedWeightKg,
    bool clearPlannedWeight = false,
    Map<String, double>? plannedWeightPlacement,
    DpvMission? mission,
    bool clearMission = false,
  }) {
    return DivePlan(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      mode: mode ?? this.mode,
      altitude: clearAltitude ? null : (altitude ?? this.altitude),
      startDateTime: clearStartDateTime
          ? null
          : (startDateTime ?? this.startDateTime),
      waterType: clearWaterType ? null : (waterType ?? this.waterType),
      salinityPpt: clearSalinityPpt ? null : (salinityPpt ?? this.salinityPpt),
      gfLow: clearGfLow ? null : (gfLow ?? this.gfLow),
      gfHigh: clearGfHigh ? null : (gfHigh ?? this.gfHigh),
      descentRate: clearDescentRate ? null : (descentRate ?? this.descentRate),
      ascentRate: clearAscentRate ? null : (ascentRate ?? this.ascentRate),
      intermediateAscentRate: clearIntermediateAscentRate
          ? null
          : (intermediateAscentRate ?? this.intermediateAscentRate),
      shallowAscentRate: clearShallowAscentRate
          ? null
          : (shallowAscentRate ?? this.shallowAscentRate),
      finalAscentRate: clearFinalAscentRate
          ? null
          : (finalAscentRate ?? this.finalAscentRate),
      lastStopDepth: clearLastStopDepth
          ? null
          : (lastStopDepth ?? this.lastStopDepth),
      gasSwitchStopSeconds: clearGasSwitchStopSeconds
          ? null
          : (gasSwitchStopSeconds ?? this.gasSwitchStopSeconds),
      airBreaks: clearAirBreaks ? null : (airBreaks ?? this.airBreaks),
      airBreaksExplicitlyOff:
          airBreaksExplicitlyOff ?? this.airBreaksExplicitlyOff,
      stopMinimums: stopMinimums ?? this.stopMinimums,
      sacBottom: clearSacBottom ? null : (sacBottom ?? this.sacBottom),
      sacDeco: clearSacDeco ? null : (sacDeco ?? this.sacDeco),
      sacStressed: clearSacStressed ? null : (sacStressed ?? this.sacStressed),
      reservePressure: clearReservePressure
          ? null
          : (reservePressure ?? this.reservePressure),
      sacFactor: clearSacFactor ? null : (sacFactor ?? this.sacFactor),
      problemSolvingMinutes: clearProblemSolvingMinutes
          ? null
          : (problemSolvingMinutes ?? this.problemSolvingMinutes),
      ppO2Bottom: clearPpO2Bottom ? null : (ppO2Bottom ?? this.ppO2Bottom),
      ppO2Deco: clearPpO2Deco ? null : (ppO2Deco ?? this.ppO2Deco),
      bestMixEndMeters: clearBestMixEndMeters
          ? null
          : (bestMixEndMeters ?? this.bestMixEndMeters),
      o2Narcotic: clearO2Narcotic ? null : (o2Narcotic ?? this.o2Narcotic),
      surfaceInterval: clearSurfaceInterval
          ? null
          : (surfaceInterval ?? this.surfaceInterval),
      sourceDiveId: clearSourceDiveId
          ? null
          : (sourceDiveId ?? this.sourceDiveId),
      linkedDiveId: clearLinkedDiveId
          ? null
          : (linkedDiveId ?? this.linkedDiveId),
      setpointLow: clearSetpointLow ? null : (setpointLow ?? this.setpointLow),
      setpointHigh: clearSetpointHigh
          ? null
          : (setpointHigh ?? this.setpointHigh),
      setpointSwitchDepth: clearSetpointSwitchDepth
          ? null
          : (setpointSwitchDepth ?? this.setpointSwitchDepth),
      deviationDepthDelta: clearDeviationDepthDelta
          ? null
          : (deviationDepthDelta ?? this.deviationDepthDelta),
      deviationTimeMinutes: clearDeviationTimeMinutes
          ? null
          : (deviationTimeMinutes ?? this.deviationTimeMinutes),
      turnPressureRule: clearTurnPressureRule
          ? null
          : (turnPressureRule ?? this.turnPressureRule),
      turnPressureFraction: clearTurnPressureFraction
          ? null
          : (turnPressureFraction ?? this.turnPressureFraction),
      segments: segments ?? this.segments,
      tanks: tanks ?? this.tanks,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      gearProvenance: gearProvenance ?? this.gearProvenance,
      plannedWeightKg: clearPlannedWeight
          ? null
          : (plannedWeightKg ?? this.plannedWeightKg),
      plannedWeightPlacement: clearPlannedWeight
          ? null
          : (plannedWeightPlacement ?? this.plannedWeightPlacement),
      mission: clearMission ? null : (mission ?? this.mission),
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    notes,
    siteId,
    createdAt,
    updatedAt,
    mode,
    altitude,
    waterType,
    salinityPpt,
    startDateTime,
    gfLow,
    gfHigh,
    descentRate,
    ascentRate,
    intermediateAscentRate,
    shallowAscentRate,
    finalAscentRate,
    lastStopDepth,
    gasSwitchStopSeconds,
    airBreaks?.o2Seconds,
    airBreaks?.breakSeconds,
    airBreaksExplicitlyOff,
    stopMinimums,
    sacBottom,
    sacDeco,
    sacStressed,
    reservePressure,
    sacFactor,
    problemSolvingMinutes,
    ppO2Bottom,
    ppO2Deco,
    bestMixEndMeters,
    o2Narcotic,
    surfaceInterval,
    sourceDiveId,
    linkedDiveId,
    setpointLow,
    setpointHigh,
    setpointSwitchDepth,
    deviationDepthDelta,
    deviationTimeMinutes,
    turnPressureRule,
    turnPressureFraction,
    segments,
    tanks,
    equipmentIds,
    gearProvenance,
    plannedWeightKg,
    plannedWeightPlacement,
    mission,
  ];
}

/// Lightweight row for the saved-plans list (denormalized summary columns —
/// no engine run per row).
class DivePlanSummary extends Equatable {
  final String id;
  final String name;
  final DateTime updatedAt;
  final double? maxDepth;
  final int? runtimeSeconds;
  final int? ttsSeconds;
  final PlanMode mode;

  const DivePlanSummary({
    required this.id,
    required this.name,
    required this.updatedAt,
    this.maxDepth,
    this.runtimeSeconds,
    this.ttsSeconds,
    this.mode = PlanMode.oc,
  });

  @override
  List<Object?> get props => [
    id,
    name,
    updatedAt,
    maxDepth,
    runtimeSeconds,
    ttsSeconds,
    mode,
  ];
}
