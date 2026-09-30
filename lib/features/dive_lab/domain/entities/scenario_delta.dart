import 'package:equatable/equatable.dart';

enum DeltaUnit { seconds, meters, percent, bar, count }

enum BetterWhen { lower, higher, neutral }

enum DeltaMetric {
  runtime(DeltaUnit.seconds, BetterWhen.neutral, 300),
  ttsAtBranch(DeltaUnit.seconds, BetterWhen.lower, 120),
  decoTimeAfterBranch(DeltaUnit.seconds, BetterWhen.lower, 120),
  deepestStopAfterBranch(DeltaUnit.meters, BetterWhen.lower, 3),
  surfaceGf(DeltaUnit.percent, BetterWhen.lower, 10),
  peakGf99AfterBranch(DeltaUnit.percent, BetterWhen.lower, 10),
  cnsEnd(DeltaUnit.percent, BetterWhen.lower, 10),
  otuEnd(DeltaUnit.count, BetterWhen.lower, 50),
  maxPpO2AfterBranch(DeltaUnit.bar, BetterWhen.lower, 0.1),
  tankEndPressure(DeltaUnit.bar, BetterWhen.higher, 20),
  gasOutTime(DeltaUnit.seconds, BetterWhen.neutral, 60),
  minGasMarginAtBranch(DeltaUnit.bar, BetterWhen.higher, 20),
  ceilingViolations(DeltaUnit.count, BetterWhen.lower, 1),
  worstCeilingViolation(DeltaUnit.meters, BetterWhen.lower, 1);

  const DeltaMetric(this.unit, this.betterWhen, this.significanceScale);
  final DeltaUnit unit;
  final BetterWhen betterWhen;

  /// A delta of this size is "one unit of significance" for verdict ranking.
  final double significanceScale;
}

/// One actual-vs-counterfactual comparison.
class ScenarioDelta extends Equatable {
  const ScenarioDelta({
    required this.metric,
    required this.actual,
    required this.counterfactual,
    this.tankId,
  });
  final DeltaMetric metric;
  final double? actual;
  final double? counterfactual;
  final String? tankId;

  double? get delta => actual != null && counterfactual != null
      ? counterfactual! - actual!
      : null;

  double get significance =>
      delta == null ? 0.0 : delta!.abs() / metric.significanceScale;

  BetterWhen get betterWhen => metric.betterWhen;

  @override
  List<Object?> get props => [metric, actual, counterfactual, tankId];
}
