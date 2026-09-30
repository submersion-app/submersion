import 'package:submersion/features/dive_lab/domain/entities/scenario_consumption.dart';
import 'package:submersion/features/dive_lab/domain/entities/scenario_delta.dart';
import 'package:submersion/features/dive_log/data/services/profile_analysis_service.dart';
import 'package:submersion/features/planner/domain/entities/plan_outcome.dart';

double? _last(List<double>? curve) =>
    curve == null || curve.isEmpty ? null : curve.last;

double? _at(List<num>? curve, int i) =>
    curve == null || i < 0 || i >= curve.length ? null : curve[i].toDouble();

double? _maxAfter(List<double>? curve, int branchIndex) {
  if (curve == null || curve.length <= branchIndex + 1) return null;
  var m = double.negativeInfinity;
  for (var i = branchIndex + 1; i < curve.length; i++) {
    if (curve[i] > m) m = curve[i];
  }
  return m;
}

double _decoTimeAfter(
  ProfileAnalysis a,
  List<int> timestamps,
  int branchIndex,
) {
  var total = 0.0;
  for (
    var i = branchIndex + 1;
    i < a.ndlCurve.length && i < timestamps.length;
    i++
  ) {
    if (a.ndlCurve[i] < 0) total += timestamps[i] - timestamps[i - 1];
  }
  return total;
}

double _deepestStopAfter(ProfileAnalysis a, int branchIndex) {
  var deepest = 0.0;
  for (
    var i = branchIndex + 1;
    i < a.ndlCurve.length && i < a.decoStopCurve.length;
    i++
  ) {
    if (a.ndlCurve[i] < 0 && a.decoStopCurve[i] > deepest) {
      deepest = a.decoStopCurve[i];
    }
  }
  return deepest;
}

(int count, double worst) _violations(
  ProfileAnalysis a,
  List<double> depths,
  int branchIndex,
) {
  var count = 0;
  var worst = 0.0;
  for (
    var i = branchIndex + 1;
    i < a.ceilingCurve.length && i < depths.length;
    i++
  ) {
    final excess = a.ceilingCurve[i] - depths[i];
    if (excess > 0.1) {
      count++;
      if (excess > worst) worst = excess;
    }
  }
  return (count, worst);
}

/// Every like-for-like comparison the delta panel shows. Entries whose
/// inputs do not exist on either side are omitted (gas-out, min gas).
List<ScenarioDelta> buildDeltas({
  required ProfileAnalysis actual,
  required ProfileAnalysis counterfactual,
  required List<double> actualDepths,
  required List<double> counterfactualDepths,
  required List<int> actualTimestamps,
  required List<int> counterfactualTimestamps,
  required int branchIndex,
  required ScenarioConsumption consumption,
  PlanOutcome? planOutcome,
  double? branchBackGasPressureBar,
}) {
  final deltas = <ScenarioDelta>[];
  void add(DeltaMetric m, double? a, double? c, {String? tankId}) => deltas.add(
    ScenarioDelta(metric: m, actual: a, counterfactual: c, tankId: tankId),
  );

  add(
    DeltaMetric.runtime,
    (actualTimestamps.last - actualTimestamps.first).toDouble(),
    (counterfactualTimestamps.last - counterfactualTimestamps.first).toDouble(),
  );
  add(
    DeltaMetric.ttsAtBranch,
    _at(actual.ttsCurve, branchIndex),
    _at(counterfactual.ttsCurve, branchIndex),
  );
  add(
    DeltaMetric.decoTimeAfterBranch,
    _decoTimeAfter(actual, actualTimestamps, branchIndex),
    _decoTimeAfter(counterfactual, counterfactualTimestamps, branchIndex),
  );
  add(
    DeltaMetric.deepestStopAfterBranch,
    _deepestStopAfter(actual, branchIndex),
    _deepestStopAfter(counterfactual, branchIndex),
  );
  add(
    DeltaMetric.surfaceGf,
    _last(actual.surfaceGfCurve),
    _last(counterfactual.surfaceGfCurve),
  );
  add(
    DeltaMetric.peakGf99AfterBranch,
    _maxAfter(actual.gfCurve, branchIndex),
    _maxAfter(counterfactual.gfCurve, branchIndex),
  );
  add(
    DeltaMetric.cnsEnd,
    _last(actual.cnsCurve),
    _last(counterfactual.cnsCurve),
  );
  add(
    DeltaMetric.otuEnd,
    _last(actual.otuCurve),
    _last(counterfactual.otuCurve),
  );
  add(
    DeltaMetric.maxPpO2AfterBranch,
    _maxAfter(actual.ppO2Curve, branchIndex),
    _maxAfter(counterfactual.ppO2Curve, branchIndex),
  );

  for (final c in consumption.counterfactual) {
    final a = consumption.actualFor(c.tankId);
    add(
      DeltaMetric.tankEndPressure,
      a?.endPressureBar,
      c.endPressureBar,
      tankId: c.tankId,
    );
    if (c.emptyAtSeconds != null || a?.emptyAtSeconds != null) {
      add(
        DeltaMetric.gasOutTime,
        a?.emptyAtSeconds?.toDouble(),
        c.emptyAtSeconds?.toDouble(),
        tankId: c.tankId,
      );
    }
  }

  if (planOutcome != null && branchBackGasPressureBar != null) {
    for (final u in planOutcome.tankUsages) {
      final minGas = u.minGasBar;
      if (minGas != null) {
        add(
          DeltaMetric.minGasMarginAtBranch,
          null,
          branchBackGasPressureBar - minGas,
          tankId: u.tankId,
        );
        break;
      }
    }
  }

  final av = _violations(actual, actualDepths, branchIndex);
  final cv = _violations(counterfactual, counterfactualDepths, branchIndex);
  add(DeltaMetric.ceilingViolations, av.$1.toDouble(), cv.$1.toDouble());
  add(DeltaMetric.worstCeilingViolation, av.$2, cv.$2);
  return deltas;
}

/// The leading non-zero deltas by significance, for the verdict sentence.
List<ScenarioDelta> selectVerdictDeltas(
  List<ScenarioDelta> deltas, {
  int count = 3,
}) {
  final ranked =
      deltas.where((d) => d.delta != null && d.delta!.abs() > 1e-9).toList()
        ..sort((a, b) => b.significance.compareTo(a.significance));
  return ranked.take(count).toList();
}
