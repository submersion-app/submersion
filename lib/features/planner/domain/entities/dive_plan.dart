import 'package:equatable/equatable.dart';

import 'package:submersion/core/constants/enums.dart';
import 'package:submersion/core/deco/schedule_policy.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// Breathing mode of a saved dive plan.
///
/// [scr] is a constant-mass-flow semi-closed rebreather; [pscr] is a
/// passive-addition semi-closed rebreather (ventilation-coupled fresh gas).
enum PlanMode { oc, ccr, scr, pscr }

/// Gas turn-pressure rule for penetration planning (Phase 5).
enum TurnPressureRule { allUsable, halves, thirds, custom }

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
  /// density. Null with a null [waterType] is EN13319 standard water.
  final double? salinityPpt;

  /// Planned start time; null = "now" at planning. Drives repetitive tissue
  /// init and overlap detection (v120).
  final DateTime? startDateTime;

  // Deco settings
  final int gfLow;
  final int gfHigh;
  final double descentRate;

  /// Working ascent rate in m/min: leaving the bottom for the first stop.
  final double ascentRate;

  /// Ascent rate in m/min between intermediate (deeper than 9 m) stops -
  /// slower than [ascentRate], because a diver climbing the stop grid is not
  /// leaving the bottom.
  final double intermediateAscentRate;

  /// Ascent rate in m/min between shallow (9 m and above) stops.
  final double shallowAscentRate;

  /// Ascent rate in m/min from the last stop to the surface. The shallowest
  /// part of the ascent is where a depth change costs the most pressure
  /// change, so it is the slowest of the four.
  final double finalAscentRate;

  final double lastStopDepth;
  final int gasSwitchStopSeconds;
  final AirBreakPolicy? airBreaks;

  // Gas planning
  final double sacBottom;
  final double? sacDeco;
  final double? sacStressed;
  final double reservePressure;

  // Repetitive context
  final Duration? surfaceInterval;
  final String? sourceDiveId;
  final String? linkedDiveId;

  // CCR config (Phase 4 UI; persisted now)
  final double? setpointLow;
  final double? setpointHigh;
  final double? setpointSwitchDepth;

  // Contingency config (Phase 5 UI; persisted now)
  final double deviationDepthDelta;
  final int deviationTimeMinutes;
  final TurnPressureRule? turnPressureRule;
  final double? turnPressureFraction;

  // Content
  final List<PlanSegment> segments;
  final List<DiveTank> tanks;

  // Gear & Weights (v104): equipment attached to the plan plus the accepted
  // weight-prediction snapshot (placement keyed by WeightType.name -> kg).
  final List<String> equipmentIds;
  final double? plannedWeightKg;
  final Map<String, double>? plannedWeightPlacement;

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
    required this.gfLow,
    required this.gfHigh,
    this.descentRate = 18.0,
    this.ascentRate = 9.0,
    this.intermediateAscentRate = 6.0,
    this.shallowAscentRate = 3.0,
    this.finalAscentRate = 1.0,
    this.lastStopDepth = 3.0,
    this.gasSwitchStopSeconds = 0,
    this.airBreaks,
    this.sacBottom = 15.0,
    this.sacDeco,
    this.sacStressed,
    this.reservePressure = 50.0,
    this.surfaceInterval,
    this.sourceDiveId,
    this.linkedDiveId,
    this.setpointLow,
    this.setpointHigh,
    this.setpointSwitchDepth,
    this.deviationDepthDelta = 5.0,
    this.deviationTimeMinutes = 5,
    this.turnPressureRule,
    this.turnPressureFraction,
    this.segments = const [],
    this.tanks = const [],
    this.equipmentIds = const [],
    this.plannedWeightKg,
    this.plannedWeightPlacement,
  });

  /// CCR setpoints with the spec defaults (0.7 shallow, 1.3 below 10 m).
  double get effectiveSetpointLow => setpointLow ?? 0.7;
  double get effectiveSetpointHigh => setpointHigh ?? 1.3;
  double get effectiveSetpointSwitchDepth => setpointSwitchDepth ?? 10.0;

  /// Deco SAC: explicit value or the 0.8x-of-bottom default.
  double get sacDecoEffective => sacDeco ?? sacBottom * 0.8;

  /// Stressed (bailout/rock-bottom) SAC: explicit or 2.5x bottom.
  double get sacStressedEffective => sacStressed ?? sacBottom * 2.5;

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
    int? gfHigh,
    double? descentRate,
    double? ascentRate,
    double? intermediateAscentRate,
    double? shallowAscentRate,
    double? finalAscentRate,
    double? lastStopDepth,
    int? gasSwitchStopSeconds,
    AirBreakPolicy? airBreaks,
    bool clearAirBreaks = false,
    double? sacBottom,
    double? sacDeco,
    bool clearSacDeco = false,
    double? sacStressed,
    bool clearSacStressed = false,
    double? reservePressure,
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
    int? deviationTimeMinutes,
    TurnPressureRule? turnPressureRule,
    bool clearTurnPressureRule = false,
    double? turnPressureFraction,
    bool clearTurnPressureFraction = false,
    List<PlanSegment>? segments,
    List<DiveTank>? tanks,
    List<String>? equipmentIds,
    double? plannedWeightKg,
    bool clearPlannedWeight = false,
    Map<String, double>? plannedWeightPlacement,
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
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      descentRate: descentRate ?? this.descentRate,
      ascentRate: ascentRate ?? this.ascentRate,
      intermediateAscentRate:
          intermediateAscentRate ?? this.intermediateAscentRate,
      shallowAscentRate: shallowAscentRate ?? this.shallowAscentRate,
      finalAscentRate: finalAscentRate ?? this.finalAscentRate,
      lastStopDepth: lastStopDepth ?? this.lastStopDepth,
      gasSwitchStopSeconds: gasSwitchStopSeconds ?? this.gasSwitchStopSeconds,
      airBreaks: clearAirBreaks ? null : (airBreaks ?? this.airBreaks),
      sacBottom: sacBottom ?? this.sacBottom,
      sacDeco: clearSacDeco ? null : (sacDeco ?? this.sacDeco),
      sacStressed: clearSacStressed ? null : (sacStressed ?? this.sacStressed),
      reservePressure: reservePressure ?? this.reservePressure,
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
      deviationDepthDelta: deviationDepthDelta ?? this.deviationDepthDelta,
      deviationTimeMinutes: deviationTimeMinutes ?? this.deviationTimeMinutes,
      turnPressureRule: clearTurnPressureRule
          ? null
          : (turnPressureRule ?? this.turnPressureRule),
      turnPressureFraction: clearTurnPressureFraction
          ? null
          : (turnPressureFraction ?? this.turnPressureFraction),
      segments: segments ?? this.segments,
      tanks: tanks ?? this.tanks,
      equipmentIds: equipmentIds ?? this.equipmentIds,
      plannedWeightKg: clearPlannedWeight
          ? null
          : (plannedWeightKg ?? this.plannedWeightKg),
      plannedWeightPlacement: clearPlannedWeight
          ? null
          : (plannedWeightPlacement ?? this.plannedWeightPlacement),
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
    sacBottom,
    sacDeco,
    sacStressed,
    reservePressure,
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
    plannedWeightKg,
    plannedWeightPlacement,
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
