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

  /// A loop plan goes deeper than the MOD of every bailout gas it carries
  /// (#3961). [PlanIssue.value] is the plan's deepest point and
  /// [PlanIssue.threshold] the deepest MOD carried, both in meters.
  noEligibleBailoutGas,
  minGasViolation,

  /// A back gas whose rock-bottom minimum is at or above its fill, so no
  /// gas is usable before the turn (#3741). [PlanIssue.value] is the
  /// minimum gas and [PlanIssue.threshold] the start pressure, both in bar.
  noUsableGas,
  diluentModExceeded,

  /// An authored segment takes the diver shallower than the deco ceiling,
  /// skipping stops the plan still owes (#3354). Unlike the limit-exceeded
  /// types, [PlanIssue.value] is the ceiling (the depth the diver had to
  /// stay at) and [PlanIssue.threshold] the depth they were actually at, so
  /// grouping by the highest value keeps the deepest ceiling.
  ceilingViolated,
}

/// One issue found while computing a plan.
class PlanIssue extends Equatable {
  final PlanIssueType type;
  final PlanIssueSeverity severity;
  final String message;

  /// Elapsed dive time, in seconds, at which the issue first starts: where
  /// a limit is first passed, a running total first reaches its threshold or
  /// a cylinder first drops below its limit. The chart marks the issue here
  /// (#3738). 0 when the dive starts with it, as a repetitive dive can; null
  /// for an issue with no single moment, such as a missing deco gas.
  final int? atRuntime;

  /// The depth the issue's message names, such as the deepest point of the
  /// leg a limit is passed on. Not necessarily the depth at [atRuntime].
  final double? atDepth;
  final String? segmentId;

  /// The cylinder a gas issue is about.
  final String? tankId;
  final double? value;
  final double? threshold;

  const PlanIssue({
    required this.type,
    required this.severity,
    required this.message,
    this.atRuntime,
    this.atDepth,
    this.segmentId,
    this.tankId,
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
    tankId,
    value,
    threshold,
  ];
}

/// A computed decompression stop with its gas and arrival time.
class PlanStop extends Equatable {
  final double depthMeters;
  final int durationSeconds;
  final int airBreakSeconds;

  /// The stop's cylinder mix, O2 fraction. On a loop this is the diluent or
  /// supply gas, not what the diver inspires.
  final double gasFO2;

  /// The stop's cylinder mix, He fraction. On a loop this is the diluent or
  /// supply gas, not what the diver inspires.
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

/// Why a back-gas cylinder's turn pressure or minimum gas could not be
/// worked out, so the results can name the missing input instead of
/// leaving the figure blank (#3603).
enum PlanGasLimitGap {
  /// The cylinder has no start pressure to measure from.
  noStartPressure,

  /// The cylinder has no size, so a volume of gas cannot be read as bar.
  noVolume,

  /// No turn-pressure rule applies: the plan's rule and the diver's default
  /// are both unset, or the rule is None.
  noTurnRule,
}

/// Per-tank consumption result.
class PlanTankUsage extends Equatable {
  final String tankId;
  final double litersUsed;

  /// Surface liters in the cylinder at the start of the plan; null when the
  /// tank has no size or start pressure.
  final double? totalLiters;
  final double? remainingPressure;

  /// Fill pressure at the start of the plan, in bar.
  final double? startPressure;
  final double percentUsed;
  final bool reserveViolation;

  /// Turn pressure per the plan's turn-pressure rule (bottom tanks only).
  final double? turnPressureBar;

  /// Rock-bottom minimum gas for a stressed shared ascent (bottom tanks).
  final double? minGasBar;

  /// Why [turnPressureBar] is null on a cylinder it applies to; null when
  /// it was computed or when the cylinder is not one turn pressure is for.
  final PlanGasLimitGap? turnPressureGap;

  /// Why [minGasBar] is null on a cylinder it applies to; null when it was
  /// computed or when the cylinder is not one minimum gas is for.
  final PlanGasLimitGap? minGasGap;

  const PlanTankUsage({
    required this.tankId,
    required this.litersUsed,
    this.totalLiters,
    this.remainingPressure,
    this.startPressure,
    required this.percentUsed,
    this.reserveViolation = false,
    this.turnPressureBar,
    this.minGasBar,
    this.turnPressureGap,
    this.minGasGap,
  });

  /// Pressure consumed, in bar; null when start or remaining is unknown.
  double? get usedPressure {
    final start = startPressure;
    final remaining = remainingPressure;
    if (start == null || remaining == null) return null;
    final used = start - remaining;
    if (used < 0) return 0;
    if (used > start) return start;
    return used;
  }

  /// Surface liters left at the end of the plan. Negative when [litersUsed]
  /// exceeds [totalLiters] -- the cylinder is asked for more than it holds,
  /// and the shortfall is exactly as informative as the surplus a diver
  /// reads on an ordinary line (#3190).
  double? get remainingLiters {
    final total = totalLiters;
    if (total == null) return null;
    return total - litersUsed;
  }

  @override
  List<Object?> get props => [
    tankId,
    litersUsed,
    totalLiters,
    remainingPressure,
    startPressure,
    percentUsed,
    reserveViolation,
    turnPressureBar,
    minGasBar,
    turnPressureGap,
    minGasGap,
  ];
}

/// What a line of the dive plan table describes.
enum PlanScheduleRowKind {
  /// Going deeper: an authored descent.
  descent,

  /// Holding depth while the dive is still working: the bottom.
  level,

  /// Going shallower: an authored ascent, the computed leg to the first stop,
  /// or the final leg to the surface. Travel between two computed stops has
  /// no line of its own (see [PlanScheduleRow.foldedTravel]).
  ascent,

  /// Holding depth on the way up: an authored or computed stop.
  stop,
}

/// A stretch of ascent travel with no line of its own in the plan table: the
/// time is still breathed, so whatever charges gas per row reads it from here
/// (see [PlanScheduleRow.foldedTravel]).
class PlanFoldedTravel extends Equatable {
  final double fromDepthMeters;
  final double toDepthMeters;
  final int seconds;

  /// The cylinder breathed across this stretch, which is not always the one
  /// on the row: a leg into a switch stop is still on the gas it left.
  final String? tankId;

  const PlanFoldedTravel({
    required this.fromDepthMeters,
    required this.toDepthMeters,
    required this.seconds,
    required this.tankId,
  });

  @override
  List<Object?> get props => [fromDepthMeters, toDepthMeters, seconds, tankId];
}

/// One line of the dive plan table, the way a slate reads it, so a diver can
/// follow the plan against a watch: leave the bottom, reach 21 m by minute
/// 38, hold until 39, and so on. Authored legs come first, then the computed
/// ascent: the leg to the first stop, every stop, and the leg to the surface.
///
/// The lines are what a diver reads, not the whole dive: travel between stops
/// folds into the stop it leads to, so anything measuring the dive from them
/// has to read [foldedTravel] too (#3927).
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

  /// Partial pressure of O2 actually inspired on this line, bar. For a loop
  /// mode (CCR/SCR/PSCR) this is the loop's real inspired ppO2 -- the
  /// setpoint for CCR -- not ambient x the carried gas's own O2 fraction,
  /// which on a loop is a different (usually lower) number.
  final double ppO2;

  /// Equivalent Narcotic Depth at this line's depth, metres, from [gasFO2]/
  /// [gasFHe] via [GasMix.end] -- the same calculation and convention the
  /// endExceeded plan issue already uses.
  final double endMeters;

  /// The travel between stops leading into this line, deepest stretch first
  /// and split wherever the gas changes. The table folds it into this line's
  /// runtime rather than printing it (#3138), so [durationSeconds] leaves it
  /// out: [durationSeconds] alone does not add up to the dive's runtime.
  ///
  /// Filled on the plan engine's schedule. A bailout table folds its travel
  /// the same way but charges it as it builds the table, so its rows leave
  /// this empty.
  final List<PlanFoldedTravel> foldedTravel;

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
    this.ppO2 = 0.0,
    this.endMeters = 0.0,
    this.foldedTravel = const [],
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
    ppO2,
    endMeters,
    foldedTravel,
  ];
}

/// Everything the PlanEngine computes from a DivePlan.
class PlanOutcome {
  /// Total runtime: user segments + travel + stops.
  final int runtimeSeconds;
  final double maxDepth;

  /// NDL (seconds, -1 = in deco) at the deepest authored leg.
  final int ndlAtBottom;

  /// Time to surface in seconds from the end of the last authored segment:
  /// travel to the first stop, every stop, the travel between them and the
  /// final ascent. Always equals [runtimeSeconds] minus the authored
  /// runtime, so it can never disagree with the printed schedule.
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

  /// Tissue state on reaching the surface: [endTissue] carried through the
  /// computed ascent, its stops and their air breaks. What a later dive of a
  /// series starts from.
  final BuhlmannState surfacedTissue;

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
    required this.surfacedTissue,
    required this.ceilingTrace,
    this.authoredDecoSeconds = 0,
  });

  /// Time spent on stops the diver authored as segments (a stop leg in the
  /// resolved chain), as opposed to the [stops] the engine scheduled after
  /// the last segment.
  final int authoredDecoSeconds;

  /// No critical issue present.
  bool get isDiveable =>
      !issues.any((i) => i.severity == PlanIssueSeverity.critical);

  int get totalDecoSeconds =>
      authoredDecoSeconds + stops.fold(0, (sum, s) => sum + s.durationSeconds);
}
