import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_target.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';

/// Average ascent rate over the last 12 months above the common 9 m/min
/// guidance. Fires only above it: a slower rate is never praised.
List<Observation> ascentRateRule(ObservationInputs inputs) {
  final rate = inputs.recentAscentRate;
  if (rate == null ||
      rate <= ObservationThresholds.ascentRateGuidanceLowMPerMin) {
    return const [];
  }
  final profiled = inputs.dives
      .where((d) => d.hasProfile && inputs.inRecentYear(d.date))
      .length;
  if (profiled < ObservationThresholds.ascentRateMinDives) return const [];
  return [
    Observation(
      ruleId: ObservationRuleId.ascentRate,
      fingerprint: '${rate.floor()}',
      score: rate,
      facts: RateFacts(metersPerMin: rate, dives: profiled),
      target: const InsightsCategoryTarget('profile'),
    ),
  ];
}
