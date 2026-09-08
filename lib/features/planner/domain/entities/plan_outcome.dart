import 'package:equatable/equatable.dart';

import 'package:submersion/core/deco/deco_model.dart';

/// Severity of a computed plan issue, ordered least to most severe.
enum PlanIssueSeverity { info, warning, alert, critical }

/// What went wrong (or deserves attention) in a computed plan.
enum PlanIssueType {
  ppO2High,
  ppO2Critical,
  hypoxicGas,
  endExceeded,
  gasDensityHigh,
  gasDensityCritical,
  cnsWarning,
  cnsCritical,
  otuHigh,
  gasReserveViolation,
  gasOut,
  ndlExceededNoDecoGas,
  noBailoutCarried,
  minGasViolation,
}

/// One issue found while computing a plan.
class PlanIssue extends Equatable {
  final PlanIssueType type;
  final PlanIssueSeverity severity;
  final String message;
  final int? atRuntime;
  final double? atDepth;
  final String? segmentId;
  final double? value;
  final double? threshold;

  const PlanIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.atRuntime,
    this.atDepth,
    this.segmentId,
    this.value,
    this.threshold,
  });

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

/// A computed decompression stop with its gas and arrival time.
class PlanStop extends Equatable {
  final double depthMeters;
  final int durationSeconds;
  final int airBreakSeconds;
  final double gasFO2;
  final double gasFHe;
  final String? tankId;
  final int arrivalRuntimeSeconds;

  const PlanStop({
    required this.depthMeters,
    required this.durationSeconds,
    this.airBreakSeconds = 0,
    required this.gasFO2,
    required this.gasFHe,
    this.tankId,
    required this.arrivalRuntimeSeconds,
  });

  @override
  List<Object?> get props => [
    depthMeters,
    durationSeconds,
    airBreakSeconds,
    gasFO2,
    gasFHe,
    tankId,
    arrivalRuntimeSeconds,
  ];
}

/// Deco/exposure state at the end of one user-authored segment.
class SegmentOutcome extends Equatable {
  final String segmentId;
  final int startRuntime;
  final int endRuntime;
  final int ndlAtEnd;
  final double ceilingAtEnd;
  final int ttsAtEnd;
  final double cns;
  final double otu;
  final double maxPpO2;

  const SegmentOutcome({
    required this.segmentId,
    required this.startRuntime,
    required this.endRuntime,
    required this.ndlAtEnd,
    required this.ceilingAtEnd,
    required this.ttsAtEnd,
    required this.cns,
    required this.otu,
    required this.maxPpO2,
  });

  bool get inDeco => ndlAtEnd < 0;

  @override
  List<Object?> get props => [
    segmentId,
    startRuntime,
    endRuntime,
    ndlAtEnd,
    ceilingAtEnd,
    ttsAtEnd,
    cns,
    otu,
    maxPpO2,
  ];
}

/// Per-tank consumption result.
class PlanTankUsage extends Equatable {
  final String tankId;
  final double litersUsed;
  final double? remainingPressure;
  final double percentUsed;
  final bool reserveViolation;

  /// Turn pressure per the plan's turn-pressure rule (bottom tanks only).
  final double? turnPressureBar;

  /// Rock-bottom minimum gas for a stressed shared ascent (bottom tanks).
  final double? minGasBar;

  const PlanTankUsage({
    required this.tankId,
    required this.litersUsed,
    this.remainingPressure,
    required this.percentUsed,
    this.reserveViolation = false,
    this.turnPressureBar,
    this.minGasBar,
  });

  @override
  List<Object?> get props => [
    tankId,
    litersUsed,
    remainingPressure,
    percentUsed,
    reserveViolation,
    turnPressureBar,
    minGasBar,
  ];
}

/// What a line of the dive plan table describes.
enum PlanScheduleRowKind {
  /// Going deeper: an authored descent.
  descent,

  /// Holding depth while the dive is still working: the bottom.
  level,

  /// Going shallower: an authored ascent, a computed travel leg between
  /// stops, or the final leg to the surface.
  ascent,

  /// Holding depth on the way up: an authored or computed stop.
  stop,
}

/// One line of the dive plan table, the way a slate reads it: every travel
/// leg is a line and every stop is a line, so a diver can follow the plan
/// against a watch - leave the bottom, reach 21 m by minute 38, hold until
/// 39, and so on. Authored legs come first, then the computed ascent.
class PlanScheduleRow extends Equatable {
  final PlanScheduleRowKind kind;

  /// Depth at the END of the line: where a travel leg arrives, or the depth
  /// a stop or level holds.
  final double depthMeters;
  final int durationSeconds;

  /// Elapsed dive time at the END of the line, in seconds.
  final int runtimeSeconds;
  final double gasFO2;
  final double gasFHe;
  final String? tankId;

  /// True on the first line and wherever the breathed gas differs from the
  /// line before, which is what the table highlights: a diver scans for the
  /// switches, not for the gas repeated on every line.
  final bool gasSwitch;
  final int airBreakSeconds;

  const PlanScheduleRow({
    required this.kind,
    required this.depthMeters,
    required this.durationSeconds,
    required this.runtimeSeconds,
    required this.gasFO2,
    required this.gasFHe,
    this.tankId,
    this.gasSwitch = false,
    this.airBreakSeconds = 0,
  });

  /// Elapsed dive time when this line BEGINS, in seconds.
  int get startRuntimeSeconds => runtimeSeconds - durationSeconds;

  @override
  List<Object?> get props => [
    kind,
    depthMeters,
    durationSeconds,
    runtimeSeconds,
    gasFO2,
    gasFHe,
    tankId,
    gasSwitch,
    airBreakSeconds,
  ];
}

/// Everything the PlanEngine computes from a DivePlan.
class PlanOutcome {
  /// Total runtime: user segments + travel + stops.
  final int runtimeSeconds;
  final double maxDepth;

  /// NDL (seconds, -1 = in deco) and TTS at the bottom reference point.
  final int ndlAtBottom;
  final int ttsAtBottom;

  final List<PlanStop> stops;

  /// The whole dive as table lines: authored legs, then every computed
  /// travel leg and stop, ending with the leg to the surface. Empty when the
  /// plan has no segments.
  final List<PlanScheduleRow> schedule;
  final List<SegmentOutcome> segmentOutcomes;
  final List<PlanTankUsage> tankUsages;
  final double cnsEnd;
  final double otuTotal;

  /// Severity-sorted, most severe first.
  final List<PlanIssue> issues;

  /// Tissue state at the end of the user-authored segments (before the
  /// computed ascent), plus the per-segment timeline for scrubbing.
  final BuhlmannState endTissue;
  final List<(int runtimeSeconds, BuhlmannState state)> tissueTimeline;

  /// The deco ceiling sampled at a fixed 30-second interval (see
  /// `PlanEngine.ceilingSampleSeconds`) across the whole dive (user segments
  /// plus the computed ascent and stops), so the chart can draw it as the
  /// continuous rise-then-fall curve it actually is instead of jumping
  /// straight from one stop's own depth to the next.
  ///
  /// The trace always ends clear of the surface: the last sample is below
  /// the chart's clear-ceiling epsilon, so the shaded no-go band closes
  /// instead of trailing along the surface for the rest of the dive.
  final List<(int runtimeSeconds, double ceilingMeters)> ceilingTrace;

  const PlanOutcome({
    required this.runtimeSeconds,
    required this.maxDepth,
    required this.ndlAtBottom,
    required this.ttsAtBottom,
    required this.stops,
    this.schedule = const [],
    required this.segmentOutcomes,
    required this.tankUsages,
    required this.cnsEnd,
    required this.otuTotal,
    required this.issues,
    required this.endTissue,
    required this.tissueTimeline,
    required this.ceilingTrace,
  });

  /// No critical issue present.
  bool get isDiveable =>
      !issues.any((i) => i.severity == PlanIssueSeverity.critical);

  int get totalDecoSeconds =>
      stops.fold(0, (sum, s) => sum + s.durationSeconds);
}
