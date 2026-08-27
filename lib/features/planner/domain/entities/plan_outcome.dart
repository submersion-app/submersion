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

/// Everything the PlanEngine computes from a DivePlan.
class PlanOutcome {
  /// Total runtime: user segments + travel + stops.
  final int runtimeSeconds;
  final double maxDepth;

  /// NDL (seconds, -1 = in deco) and TTS at the bottom reference point.
  final int ndlAtBottom;
  final int ttsAtBottom;

  final List<PlanStop> stops;
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

  const PlanOutcome({
    required this.runtimeSeconds,
    required this.maxDepth,
    required this.ndlAtBottom,
    required this.ttsAtBottom,
    required this.stops,
    required this.segmentOutcomes,
    required this.tankUsages,
    required this.cnsEnd,
    required this.otuTotal,
    required this.issues,
    required this.endTissue,
    required this.tissueTimeline,
  });

  /// No critical issue present.
  bool get isDiveable =>
      !issues.any((i) => i.severity == PlanIssueSeverity.critical);

  int get totalDecoSeconds =>
      stops.fold(0, (sum, s) => sum + s.durationSeconds);
}
