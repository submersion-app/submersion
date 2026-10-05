import 'package:submersion/features/insights/domain/observations/effect_size.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

typedef _Sample = ({DateTime date, double value});

List<Observation> _one(Observation? o) => o == null ? const [] : [o];

String _percentBand(TrendFacts f) =>
    (f.percentChange.abs() / ObservationThresholds.percentBandWidth)
        .floor()
        .toString();

/// The shared gate for per-dive mean trends (spec section 4.1): at least 8
/// dives in each period, the rule's own minimum, and effect size >= 0.5.
Observation? _meanTrend({
  required ObservationRuleId rule,
  required ObservationInputs inputs,
  required Iterable<_Sample> samples,
  required bool Function(TrendFacts facts) passesMinimum,
  required String Function(TrendFacts facts) band,
  required ObservationTarget target,
}) {
  final recent = <double>[];
  final previous = <double>[];
  for (final s in samples) {
    if (inputs.inRecentYear(s.date)) {
      recent.add(s.value);
    } else if (inputs.inPreviousYear(s.date)) {
      previous.add(s.value);
    }
  }
  const minDives = ObservationThresholds.trendMinDivesPerPeriod;
  if (recent.length < minDives || previous.length < minDives) return null;
  final facts = TrendFacts(
    recent: meanOf(recent),
    previous: meanOf(previous),
    recentDives: recent.length,
    previousDives: previous.length,
  );
  if (!passesMinimum(facts)) return null;
  final d = effectSize(recent, previous);
  if (d == null || d < ObservationThresholds.trendMinEffectSize) return null;
  return Observation(
    ruleId: rule,
    fingerprint: '${facts.direction.name}:${band(facts)}',
    score: d,
    facts: facts,
    target: target,
  );
}

bool Function(TrendFacts) _minPercent(double percent) =>
    (f) => f.previous > 0 && f.percentChange.abs() >= percent;

List<Observation> rmvTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.rmvTrend,
    inputs: inputs,
    samples: inputs.rmvPerDive.map((v) => (date: v.date, value: v.value)),
    passesMinimum: _minPercent(ObservationThresholds.rmvMinPercent),
    band: _percentBand,
    target: const InsightsCategoryTarget('gas'),
  ),
);

List<Observation> maxDepthTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.maxDepthTrend,
    inputs: inputs,
    samples: [
      for (final d in inputs.dives)
        if ((d.maxDepthM ?? 0) > 0) (date: d.date, value: d.maxDepthM!),
    ],
    passesMinimum: _minPercent(ObservationThresholds.maxDepthMinPercent),
    band: _percentBand,
    target: const InsightsCategoryTarget('progression'),
  ),
);

/// Runtime in minutes; bottom time is never substituted.
List<Observation> diveTimeTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.diveTimeTrend,
    inputs: inputs,
    samples: [
      for (final d in inputs.dives)
        if ((d.runtimeSeconds ?? 0) > 0)
          (date: d.date, value: d.runtimeSeconds! / 60),
    ],
    passesMinimum: _minPercent(ObservationThresholds.diveTimeMinPercent),
    band: _percentBand,
    target: const InsightsCategoryTarget('progression'),
  ),
);

List<Observation> weightTrendRule(ObservationInputs inputs) => _one(
  _meanTrend(
    rule: ObservationRuleId.weightTrend,
    inputs: inputs,
    samples: [
      for (final d in inputs.dives)
        if (d.weightKg != null) (date: d.date, value: d.weightKg!),
    ],
    passesMinimum: (f) =>
        (f.recent - f.previous).abs() >= ObservationThresholds.weightMinKg,
    band: (f) =>
        ((f.recent - f.previous).abs() / ObservationThresholds.weightBandKg)
            .floor()
            .toString(),
    target: const InsightsCategoryTarget('equipment'),
  ),
);

/// Dive counts per period. The log must start before the previous window,
/// or a diver who began logging mid-window would read as "more dives".
List<Observation> frequencyTrendRule(ObservationInputs inputs) {
  if (inputs.dives.isEmpty ||
      inputs.dives.first.date.isAfter(inputs.previousStart)) {
    return const [];
  }
  final recent = inputs.dives.where((d) => inputs.inRecentYear(d.date)).length;
  final previous = inputs.dives
      .where((d) => inputs.inPreviousYear(d.date))
      .length;
  if (previous == 0) return const [];
  final facts = TrendFacts(
    recent: recent.toDouble(),
    previous: previous.toDouble(),
    recentDives: recent,
    previousDives: previous,
  );
  if (facts.percentChange.abs() < ObservationThresholds.frequencyMinPercent ||
      (recent - previous).abs() < ObservationThresholds.frequencyMinDives) {
    return const [];
  }
  return [
    Observation(
      ruleId: ObservationRuleId.frequencyTrend,
      fingerprint: '${facts.direction.name}:${_percentBand(facts)}',
      score: facts.percentChange.abs() / 100,
      facts: facts,
      target: const InsightsCategoryTarget('time-patterns'),
    ),
  ];
}
