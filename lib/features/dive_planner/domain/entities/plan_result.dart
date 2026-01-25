import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_planner/domain/entities/plan_segment.dart';

/// Types of warnings that can occur during dive planning.
enum PlanWarningType {
  /// ppO₂ exceeds safe working limit (typically 1.4 bar)
  ppO2High,

  /// ppO₂ exceeds deco limit (typically 1.6 bar)
  ppO2Critical,

  /// NDL exceeded, dive has deco obligation
  ndlExceeded,

  /// Tank pressure running low
  gasLow,

  /// Tank will be empty before end of segment
  gasOut,

  /// CNS% approaching warning threshold
  cnsWarning,

  /// CNS% exceeds safe limit
  cnsCritical,

  /// OTU accumulation high
  otuWarning,

  /// Ascent rate exceeds safe limit
  ascentRateHigh,

  /// Equivalent Narcotic Depth too high
  endHigh,

  /// Minimum gas reserve not maintained
  minGasViolation,

  /// Gas switch attempted above MOD
  modViolation,
}

/// Severity levels for plan warnings.
enum PlanWarningSeverity {
  /// Informational - no action required
  info,

  /// Warning - plan should be reviewed
  warning,

  /// Alert - plan has safety issues that should be addressed
  alert,

  /// Critical - plan has serious safety problems
  critical,
}

/// A warning or issue detected in the dive plan.
class PlanWarning extends Equatable {
  /// Type of warning.
  final PlanWarningType type;

  /// Severity level.
  final PlanWarningSeverity severity;

  /// Human-readable warning message.
  final String message;

  /// Runtime (seconds from dive start) when warning occurs, if applicable.
  final int? atRuntime;

  /// Depth at which warning occurs, if applicable.
  final double? atDepth;

  /// Segment ID where warning occurs, if applicable.
  final String? segmentId;

  /// The problematic value (e.g., ppO₂ value, CNS%).
  final double? value;

  /// The threshold that was exceeded.
  final double? threshold;

  const PlanWarning({
    required this.type,
    required this.severity,
    required this.message,
    this.atRuntime,
    this.atDepth,
    this.segmentId,
    this.value,
    this.threshold,
  });

  /// Icon to display for this warning type.
  String get icon {
    switch (severity) {
      case PlanWarningSeverity.info:
        return 'ℹ️';
      case PlanWarningSeverity.warning:
        return '⚠️';
      case PlanWarningSeverity.alert:
        return '🚨';
      case PlanWarningSeverity.critical:
        return '🛑';
    }
  }

  @override
  List<Object?> get props => [
    type,
    severity,
    message,
    atRuntime,
    atDepth,
    segmentId,
    value,
    threshold,
  ];
}

/// Gas consumption projection for a single tank.
class GasConsumption extends Equatable {
  /// Tank ID this consumption applies to.
  final String tankId;

  /// Tank name for display.
  final String? tankName;

  /// Gas mix in this tank.
  final GasMix gasMix;

  /// Total gas used in liters at surface pressure.
  final double gasUsedLiters;

  /// Pressure used in bar.
  final double gasUsedBar;

  /// Starting pressure in bar.
  final int? startPressure;

  /// Projected remaining pressure at end of dive.
  final int? remainingPressure;

  /// Percentage of tank used.
  final double percentUsed;

  /// Minimum gas reserve required for this tank (bar).
  final int? minGasReserve;

  /// Whether reserve is violated.
  final bool reserveViolation;

  const GasConsumption({
    required this.tankId,
    this.tankName,
    required this.gasMix,
    required this.gasUsedLiters,
    required this.gasUsedBar,
    this.startPressure,
    this.remainingPressure,
    required this.percentUsed,
    this.minGasReserve,
    this.reserveViolation = false,
  });

  /// Formatted remaining pressure.
  String get remainingFormatted {
    if (remainingPressure == null) return '--';
    if (remainingPressure! <= 0) return 'EMPTY';
    return '${remainingPressure}bar';
  }

  /// Formatted percentage used.
  String get percentFormatted => '${percentUsed.toStringAsFixed(0)}%';

  @override
  List<Object?> get props => [
    tankId,
    tankName,
    gasMix,
    gasUsedLiters,
    gasUsedBar,
    startPressure,
    remainingPressure,
    percentUsed,
    minGasReserve,
    reserveViolation,
  ];
}

/// A decompression stop in the plan.
class DecoStop extends Equatable {
  /// Stop depth in meters.
  final double depth;

  /// Duration at this stop in seconds.
  final int durationSeconds;

  /// Gas to breathe at this stop.
  final GasMix gasMix;

  /// Tank ID to use at this stop.
  final String? tankId;

  /// Runtime when arriving at this stop.
  final int arrivalRuntime;

  const DecoStop({
    required this.depth,
    required this.durationSeconds,
    required this.gasMix,
    this.tankId,
    required this.arrivalRuntime,
  });

  /// Duration formatted as minutes.
  String get durationFormatted => '${(durationSeconds / 60).ceil()} min';

  @override
  List<Object?> get props => [
    depth,
    durationSeconds,
    gasMix,
    tankId,
    arrivalRuntime,
  ];
}

/// Results calculated for a single segment.
class SegmentResult extends Equatable {
  /// The segment these results apply to.
  final String segmentId;

  /// Runtime at start of segment (seconds).
  final int startRuntime;

  /// Runtime at end of segment (seconds).
  final int endRuntime;

  /// NDL at end of segment (seconds), -1 if in deco.
  final int ndlAtEnd;

  /// Ceiling at end of segment (meters).
  final double ceilingAtEnd;

  /// TTS at end of segment (seconds).
  final int ttsAtEnd;

  /// CNS% at end of segment.
  final double cnsAtEnd;

  /// OTU accumulated during segment.
  final double otuAccumulated;

  /// Gas consumed during segment (liters at surface).
  final double gasConsumedLiters;

  /// Maximum ppO₂ during segment.
  final double maxPpO2;

  /// Average depth during segment.
  final double avgDepth;

  const SegmentResult({
    required this.segmentId,
    required this.startRuntime,
    required this.endRuntime,
    required this.ndlAtEnd,
    required this.ceilingAtEnd,
    required this.ttsAtEnd,
    required this.cnsAtEnd,
    required this.otuAccumulated,
    required this.gasConsumedLiters,
    required this.maxPpO2,
    required this.avgDepth,
  });

  /// Whether dive is in deco obligation at end of segment.
  bool get inDeco => ndlAtEnd < 0;

  @override
  List<Object?> get props => [
    segmentId,
    startRuntime,
    endRuntime,
    ndlAtEnd,
    ceilingAtEnd,
    ttsAtEnd,
    cnsAtEnd,
    otuAccumulated,
    gasConsumedLiters,
    maxPpO2,
    avgDepth,
  ];
}

/// Complete results of dive plan calculations.
///
/// This contains all decompression data, gas consumption projections,
/// warnings, and tissue state for a planned dive.
class PlanResult extends Equatable {
  /// Total runtime of the plan in seconds.
  final int totalRuntime;

  /// Time To Surface at the deepest point in seconds.
  final int ttsAtBottom;

  /// NDL at the deepest point in seconds, -1 if deco.
  final int ndlAtBottom;

  /// Maximum depth reached in the plan.
  final double maxDepth;

  /// Maximum ceiling during the dive (meters).
  final double maxCeiling;

  /// Average depth of the dive.
  final double avgDepth;

  /// Decompression schedule (may be empty for NDL dives).
  final List<DecoStop> decoSchedule;

  /// Gas consumption per tank.
  final List<GasConsumption> gasConsumptions;

  /// Warnings and alerts detected in the plan.
  final List<PlanWarning> warnings;

  /// Tissue compartment state at end of dive.
  /// Can be used for repetitive dive planning.
  final List<TissueCompartment> endTissueState;

  /// Per-segment calculation results.
  final Map<String, SegmentResult> segmentResults;

  /// Final CNS% at end of dive.
  final double cnsEnd;

  /// Total OTU accumulated.
  final double otuTotal;

  /// Maximum ppO₂ during the dive.
  final double maxPpO2;

  /// Whether the dive has any deco obligation.
  final bool hasDecoObligation;

  const PlanResult({
    required this.totalRuntime,
    required this.ttsAtBottom,
    required this.ndlAtBottom,
    required this.maxDepth,
    required this.maxCeiling,
    required this.avgDepth,
    required this.decoSchedule,
    required this.gasConsumptions,
    required this.warnings,
    required this.endTissueState,
    required this.segmentResults,
    required this.cnsEnd,
    required this.otuTotal,
    required this.maxPpO2,
    required this.hasDecoObligation,
  });

  /// Create an empty result for initial state.
  factory PlanResult.empty() {
    return const PlanResult(
      totalRuntime: 0,
      ttsAtBottom: 0,
      ndlAtBottom: 0,
      maxDepth: 0,
      maxCeiling: 0,
      avgDepth: 0,
      decoSchedule: [],
      gasConsumptions: [],
      warnings: [],
      endTissueState: [],
      segmentResults: {},
      cnsEnd: 0,
      otuTotal: 0,
      maxPpO2: 0,
      hasDecoObligation: false,
    );
  }

  /// Total runtime formatted as MM:SS or HH:MM:SS.
  String get runtimeFormatted {
    final hours = totalRuntime ~/ 3600;
    final minutes = (totalRuntime % 3600) ~/ 60;
    final seconds = totalRuntime % 60;

    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
    }
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// TTS at bottom formatted as MM:SS.
  String get ttsFormatted {
    if (ttsAtBottom <= 0) return '--';
    final minutes = ttsAtBottom ~/ 60;
    final seconds = ttsAtBottom % 60;
    return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  /// NDL at bottom formatted as minutes or "DECO".
  String get ndlFormatted {
    if (ndlAtBottom < 0) return 'DECO';
    if (ndlAtBottom > 99 * 60) return '>99 min';
    final minutes = ndlAtBottom ~/ 60;
    return '$minutes min';
  }

  /// Whether the plan has any critical warnings.
  bool get hasCriticalWarnings =>
      warnings.any((w) => w.severity == PlanWarningSeverity.critical);

  /// Whether the plan has any alert-level warnings.
  bool get hasAlertWarnings =>
      warnings.any((w) => w.severity == PlanWarningSeverity.alert);

  /// Count of warnings by severity.
  int warningCount(PlanWarningSeverity severity) =>
      warnings.where((w) => w.severity == severity).length;

  /// Total deco time in seconds.
  int get totalDecoTime =>
      decoSchedule.fold(0, (sum, stop) => sum + stop.durationSeconds);

  /// Total deco time formatted.
  String get totalDecoTimeFormatted {
    if (totalDecoTime == 0) return 'None';
    final minutes = totalDecoTime ~/ 60;
    return '$minutes min';
  }

  @override
  List<Object?> get props => [
    totalRuntime,
    ttsAtBottom,
    ndlAtBottom,
    maxDepth,
    maxCeiling,
    avgDepth,
    decoSchedule,
    gasConsumptions,
    warnings,
    endTissueState,
    segmentResults,
    cnsEnd,
    otuTotal,
    maxPpO2,
    hasDecoObligation,
  ];
}

/// State of a dive plan being edited.
class DivePlanState extends Equatable {
  /// Unique ID for this plan.
  final String id;

  /// Name/title of the plan.
  final String name;

  /// Segments that make up the plan.
  final List<PlanSegment> segments;

  /// Tanks available for the plan.
  final List<DiveTank> tanks;

  /// Gradient factor low (0-100).
  final int gfLow;

  /// Gradient factor high (0-100).
  final int gfHigh;

  /// Surface air consumption rate in L/min.
  final double sacRate;

  /// Surface interval before this dive (for repetitive diving).
  final Duration? surfaceInterval;

  /// Initial tissue state from previous dive.
  final List<TissueCompartment>? initialTissueState;

  /// Dive site for the plan.
  final String? siteId;

  /// Altitude above sea level in meters (for altitude diving).
  final double? altitude;

  /// Notes for the plan.
  final String notes;

  /// Whether the plan has been modified since last save.
  final bool isDirty;

  /// Timestamp when plan was created.
  final DateTime createdAt;

  /// Timestamp when plan was last modified.
  final DateTime updatedAt;

  const DivePlanState({
    required this.id,
    required this.name,
    required this.segments,
    required this.tanks,
    this.gfLow = 30,
    this.gfHigh = 70,
    this.sacRate = 15.0,
    this.surfaceInterval,
    this.initialTissueState,
    this.siteId,
    this.altitude,
    this.notes = '',
    this.isDirty = false,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Create a new empty plan state.
  factory DivePlanState.empty() {
    final now = DateTime.now();
    return DivePlanState(
      id: '',
      name: 'New Dive Plan',
      segments: const [],
      tanks: const [],
      createdAt: now,
      updatedAt: now,
    );
  }

  /// Maximum depth in the plan.
  double get maxDepth {
    if (segments.isEmpty) return 0;
    double max = 0;
    for (final seg in segments) {
      if (seg.startDepth > max) max = seg.startDepth;
      if (seg.endDepth > max) max = seg.endDepth;
    }
    return max;
  }

  /// Total planned time in seconds.
  int get totalTimeSeconds =>
      segments.fold(0, (sum, seg) => sum + seg.durationSeconds);

  DivePlanState copyWith({
    String? id,
    String? name,
    List<PlanSegment>? segments,
    List<DiveTank>? tanks,
    int? gfLow,
    int? gfHigh,
    double? sacRate,
    Duration? surfaceInterval,
    List<TissueCompartment>? initialTissueState,
    String? siteId,
    double? altitude,
    String? notes,
    bool? isDirty,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool clearSurfaceInterval = false,
    bool clearInitialTissueState = false,
    bool clearSiteId = false,
    bool clearAltitude = false,
  }) {
    return DivePlanState(
      id: id ?? this.id,
      name: name ?? this.name,
      segments: segments ?? this.segments,
      tanks: tanks ?? this.tanks,
      gfLow: gfLow ?? this.gfLow,
      gfHigh: gfHigh ?? this.gfHigh,
      sacRate: sacRate ?? this.sacRate,
      surfaceInterval: clearSurfaceInterval
          ? null
          : (surfaceInterval ?? this.surfaceInterval),
      initialTissueState: clearInitialTissueState
          ? null
          : (initialTissueState ?? this.initialTissueState),
      siteId: clearSiteId ? null : (siteId ?? this.siteId),
      altitude: clearAltitude ? null : (altitude ?? this.altitude),
      notes: notes ?? this.notes,
      isDirty: isDirty ?? this.isDirty,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
    id,
    name,
    segments,
    tanks,
    gfLow,
    gfHigh,
    sacRate,
    surfaceInterval,
    initialTissueState,
    siteId,
    altitude,
    notes,
    isDirty,
    createdAt,
    updatedAt,
  ];
}
