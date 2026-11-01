import 'package:submersion/core/deco/entities/tissue_compartment.dart';
import 'package:submersion/features/dive_lab/domain/entities/compare_column.dart';
import 'package:submersion/features/dive_lab/domain/entities/dive_scenario.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_outcome.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/dive_log/domain/services/bottom_time_calculator.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

/// "Leaving the bottom" for the NDL and deco rows: the last sample at this
/// fraction of the line's max depth. Bottom time's own threshold can sit a
/// third of the way down the dive, past the deep stops, where NDL reads far
/// longer than it did at depth; this matches [PlanOutcome.ndlAtBottom], which
/// is taken at the deepest authored leg.
const double kCompareDeepPhaseFraction = 0.85;

/// Above this a planned ceiling is a real one (the planner chart's own
/// clear-ceiling epsilon).
const double _clearCeilingMeters = 0.05;

const double _depthToleranceMeters = 0.5;
const int _timeToleranceSeconds = 30;
const double _gfTolerance = 1.0;

/// The plan's column. Null when the plan has no schedule, so an
/// empty plan leaves a blank line rather than a row of zeros.
CompareColumn? plannedColumn({
  required PlanOutcome outcome,
  required double surfacePressureBar,
}) {
  if (outcome.schedule.isEmpty) return null;
  final samples = [
    (timestamp: 0, depth: 0.0),
    for (final row in outcome.schedule)
      (timestamp: row.runtimeSeconds, depth: row.depthMeters),
  ];
  final inDeco = outcome.ndlAtBottom < 0;
  final decoStart = inDeco ? _firstCeilingSeconds(outcome) : null;
  return CompareColumn(
    id: 'planned',
    kind: CompareLineKind.planned,
    maxDepthMeters: outcome.maxDepth,
    bottomTimeSeconds: BottomTimeCalculator.secondsFromSamples(samples),
    ndl: inDeco
        ? CompareDecoAt(decoStart!)
        : CompareNdlLeft(outcome.ndlAtBottom),
    decoRequiredSeconds: outcome.totalDecoSeconds,
    runtimeSeconds: outcome.runtimeSeconds,
    surfaceGf: _surfaceGf(
      outcome.surfacedTissue.compartments,
      surfacePressureBar,
    ),
    decoStartSeconds: decoStart,
  );
}

/// The dive's column. [analysis] is null for a dive with no profile, and its
/// tissue curves are empty when loading is withheld; those cells stay blank.
CompareColumn divedColumn({
  required Dive dive,
  required List<DiveProfilePoint> profile,
  required ProfileAnalysis? analysis,
}) {
  final timestamps = [for (final p in profile) p.timestamp];
  final depths = [for (final p in profile) p.depth];
  final deco = _decoFacts(timestamps, depths, analysis);
  return CompareColumn(
    id: 'dived',
    kind: CompareLineKind.asDived,
    maxDepthMeters: dive.maxDepth ?? _maxOf(depths),
    bottomTimeSeconds:
        _bottomTime(timestamps, depths, dive.runtime?.inSeconds) ??
        dive.bottomTime?.inSeconds,
    ndl: deco.ndl,
    decoRequiredSeconds: deco.requiredSeconds,
    decoDoneSeconds: deco.doneSeconds,
    runtimeSeconds: dive.effectiveRuntime?.inSeconds,
    surfaceGf: _last(analysis?.surfaceGfCurve),
    decoStartSeconds: deco.startSeconds,
  );
}

/// A saved what-if's column, read off its counterfactual the way [divedColumn]
/// reads the dive, so a what-if that branches after the bottom repeats the
/// dive's own bottom time and NDL.
CompareColumn whatIfColumn({
  required DiveScenario scenario,
  required ScenarioOutcome outcome,
}) {
  final timestamps = outcome.counterfactualTimestamps;
  final depths = outcome.counterfactualDepths;
  final deco = _decoFacts(timestamps, depths, outcome.counterfactual);
  return CompareColumn(
    id: scenario.id,
    kind: CompareLineKind.whatIf,
    title: scenario.name,
    maxDepthMeters: _maxOf(depths),
    bottomTimeSeconds: _bottomTime(timestamps, depths, null),
    ndl: deco.ndl,
    decoRequiredSeconds: deco.requiredSeconds,
    decoDoneSeconds: deco.doneSeconds,
    runtimeSeconds: timestamps.isEmpty
        ? null
        : timestamps.last - timestamps.first,
    surfaceGf: _last(outcome.counterfactual.surfaceGfCurve),
    decoStartSeconds: deco.startSeconds,
  );
}

/// Whether [dived] went past [planned] on [row], by more than a rounding
/// difference. A blank on either side never does.
bool overshootsPlan(
  CompareRow row,
  CompareColumn planned,
  CompareColumn dived,
) {
  bool over(num? plan, num? actual, num tolerance) =>
      plan != null && actual != null && actual - plan > tolerance;
  return switch (row) {
    CompareRow.maxDepth => over(
      planned.maxDepthMeters,
      dived.maxDepthMeters,
      _depthToleranceMeters,
    ),
    CompareRow.bottomTime => over(
      planned.bottomTimeSeconds,
      dived.bottomTimeSeconds,
      _timeToleranceSeconds,
    ),
    CompareRow.ndl => _ndlOvershoots(planned.ndl, dived.ndl),
    CompareRow.deco => over(
      planned.decoRequiredSeconds,
      dived.decoRequiredSeconds,
      _timeToleranceSeconds,
    ),
    CompareRow.runtime => over(
      planned.runtimeSeconds,
      dived.runtimeSeconds,
      _timeToleranceSeconds,
    ),
    CompareRow.surfaceGf => over(
      planned.surfaceGf,
      dived.surfaceGf,
      _gfTolerance,
    ),
  };
}

bool _ndlOvershoots(CompareNdl? planned, CompareNdl? dived) =>
    switch ((planned, dived)) {
      (CompareNdlLeft(), CompareDecoAt()) => true,
      (CompareNdlLeft(:final seconds), CompareNdlLeft(seconds: final left)) =>
        seconds - left > _timeToleranceSeconds,
      (
        CompareDecoAt(:final runtimeSeconds),
        CompareDecoAt(runtimeSeconds: final at),
      ) =>
        runtimeSeconds - at > _timeToleranceSeconds,
      _ => false,
    };

/// When the plan's ceiling first lifts off the surface. The trace is sampled
/// every 30 seconds; a plan in deco with no such sample falls back to the end
/// of its authored legs, where [PlanOutcome.ndlAtBottom] read it.
int _firstCeilingSeconds(PlanOutcome outcome) {
  for (final (runtime, ceiling) in outcome.ceilingTrace) {
    if (ceiling > _clearCeilingMeters) return runtime;
  }
  return outcome.runtimeSeconds - outcome.ttsAtBottom;
}

double? _surfaceGf(List<TissueCompartment> compartments, double surfaceBar) {
  if (compartments.isEmpty) return null;
  var worst = double.negativeInfinity;
  for (final compartment in compartments) {
    final gf = compartment.gradientFactor(surfaceBar);
    if (gf > worst) worst = gf;
  }
  return worst < 0 ? 0 : worst * 100;
}

int? _bottomTime(List<int> timestamps, List<double> depths, int? duration) =>
    BottomTimeCalculator.secondsFromSamples([
      for (var i = 0; i < timestamps.length; i++)
        (timestamp: timestamps[i], depth: depths[i]),
    ], totalDurationSeconds: duration);

double? _maxOf(List<double> values) {
  if (values.isEmpty) return null;
  return values.reduce((a, b) => a > b ? a : b);
}

double? _last(List<double>? curve) =>
    curve == null || curve.isEmpty ? null : curve.last;

class _DecoFacts {
  const _DecoFacts({
    this.ndl,
    this.requiredSeconds,
    this.doneSeconds,
    this.startSeconds,
  });

  final CompareNdl? ndl;
  final int? requiredSeconds;
  final int? doneSeconds;
  final int? startSeconds;
}

/// Reads the NDL and deco rows from [analysis]. Blank unless its curves line
/// up with the samples, as they do not when tissue loading was withheld.
_DecoFacts _decoFacts(
  List<int> timestamps,
  List<double> depths,
  ProfileAnalysis? analysis,
) {
  final ndl = analysis?.ndlCurve;
  if (analysis == null ||
      ndl == null ||
      depths.isEmpty ||
      ndl.length != depths.length) {
    return const _DecoFacts();
  }
  final threshold = _maxOf(depths)! * kCompareDeepPhaseFraction;
  final deepEnd = depths.lastIndexWhere((d) => d >= threshold);

  var done = 0;
  for (var i = deepEnd + 1; i < ndl.length; i++) {
    if (ndl[i] < 0) done += timestamps[i] - timestamps[i - 1];
  }
  final statuses = analysis.decoStatuses;
  final required = deepEnd < statuses.length
      ? statuses[deepEnd].decoStops.fold<int>(
          0,
          (sum, stop) => sum + stop.durationSeconds,
        )
      : null;

  final firstDeco = ndl.indexWhere((n) => n < 0);
  final start = firstDeco < 0 ? null : timestamps[firstDeco];
  return _DecoFacts(
    ndl: start != null ? CompareDecoAt(start) : CompareNdlLeft(ndl[deepEnd]),
    requiredSeconds: required,
    doneSeconds: done,
    startSeconds: start,
  );
}
