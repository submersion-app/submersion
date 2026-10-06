import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_inputs.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';
import 'package:submersion/features/insights/domain/observations/rules/milestone_rules.dart';
import 'package:submersion/features/insights/domain/observations/rules/pattern_rules.dart';
import 'package:submersion/features/insights/domain/observations/rules/safety_rules.dart';
import 'package:submersion/features/insights/domain/observations/rules/trend_rules.dart';

typedef ObservationRule = List<Observation> Function(ObservationInputs inputs);

const Map<ObservationRuleId, ObservationRule> observationRules = {
  ObservationRuleId.rmvTrend: rmvTrendRule,
  ObservationRuleId.maxDepthTrend: maxDepthTrendRule,
  ObservationRuleId.diveTimeTrend: diveTimeTrendRule,
  ObservationRuleId.weightTrend: weightTrendRule,
  ObservationRuleId.frequencyTrend: frequencyTrendRule,
  ObservationRuleId.diveCountMilestone: diveCountMilestoneRule,
  ObservationRuleId.diveHoursMilestone: diveHoursMilestoneRule,
  ObservationRuleId.deepestDive: deepestDiveRule,
  ObservationRuleId.longestDive: longestDiveRule,
  ObservationRuleId.newCountry: newCountryRule,
  ObservationRuleId.newSpecies: newSpeciesRule,
  ObservationRuleId.diveGap: diveGapRule,
  ObservationRuleId.favouriteSite: favouriteSiteRule,
  ObservationRuleId.regularBuddy: regularBuddyRule,
  ObservationRuleId.busiestMonth: busiestMonthRule,
  ObservationRuleId.ascentRate: ascentRateRule,
};

/// Runs every rule not in [mutedRuleIds] (stored ids; unknown ones are
/// harmless), drops observations whose key is in [dismissedKeys], and
/// returns them ranked. A throwing rule goes to [onRuleError] and is
/// skipped, so one bad rule never hides the rest.
List<Observation> runObservationRules(
  ObservationInputs inputs, {
  Set<String> mutedRuleIds = const {},
  Set<String> dismissedKeys = const {},
  Map<ObservationRuleId, ObservationRule> rules = observationRules,
  void Function(ObservationRuleId rule, Object error, StackTrace stack)?
  onRuleError,
}) {
  final out = <Observation>[];
  for (final entry in rules.entries) {
    if (mutedRuleIds.contains(entry.key.dbValue)) continue;
    try {
      out.addAll(
        entry.value(inputs).where((o) => !dismissedKeys.contains(o.key)),
      );
    } catch (error, stack) {
      onRuleError?.call(entry.key, error, stack);
    }
  }
  return out..sort(compareObservations);
}

/// Spec section 4.4: kind tier, then score (high first), then rule
/// declaration order and fingerprint, so equal scores sort the same way
/// every time.
int compareObservations(Observation a, Observation b) {
  final byKind = a.kind.index.compareTo(b.kind.index);
  if (byKind != 0) return byKind;
  final byScore = b.score.compareTo(a.score);
  if (byScore != 0) return byScore;
  final byRule = a.ruleId.index.compareTo(b.ruleId.index);
  if (byRule != 0) return byRule;
  return a.fingerprint.compareTo(b.fingerprint);
}

/// The landing strip: the first three of [ranked], skipping any that would
/// show one kind a third time.
List<Observation> selectStrip(List<Observation> ranked) {
  final perKind = <ObservationKind, int>{};
  final out = <Observation>[];
  for (final o in ranked) {
    if (out.length == ObservationThresholds.stripSize) break;
    final n = perKind[o.kind] ?? 0;
    if (n >= ObservationThresholds.stripMaxPerKind) continue;
    perKind[o.kind] = n + 1;
    out.add(o);
  }
  return out;
}
