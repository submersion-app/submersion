import 'package:intl/intl.dart';

import 'package:submersion/core/utils/number_display.dart';
import 'package:submersion/core/utils/unit_formatter.dart';
import 'package:submersion/features/insights/domain/observations/observation.dart';
import 'package:submersion/features/insights/domain/observations/observation_facts.dart';
import 'package:submersion/features/insights/domain/observations/observation_rule_id.dart';
import 'package:submersion/features/insights/domain/observations/observation_thresholds.dart';
import 'package:submersion/l10n/arb/app_localizations.dart';

String _pct(TrendFacts t) => formatFixedForDisplay(t.percentChange.abs(), 0);

String _minutes(AppLocalizations l10n, double minutes) =>
    l10n.insights_records_longestDiveValue(minutes.round());

/// The full month name in the active language. A standalone month has no
/// field order, so the locale-derived pattern is allowed here.
String insightsMonthName(AppLocalizations l10n, int month) =>
    DateFormat.MMMM(l10n.localeName).format(DateTime(2000, month));

String observationRuleLabel(
  ObservationRuleId rule,
  AppLocalizations l10n,
) => switch (rule) {
  ObservationRuleId.rmvTrend => l10n.insights_observations_rule_rmvTrend,
  ObservationRuleId.maxDepthTrend =>
    l10n.insights_observations_rule_maxDepthTrend,
  ObservationRuleId.diveTimeTrend =>
    l10n.insights_observations_rule_diveTimeTrend,
  ObservationRuleId.weightTrend => l10n.insights_observations_rule_weightTrend,
  ObservationRuleId.frequencyTrend =>
    l10n.insights_observations_rule_frequencyTrend,
  ObservationRuleId.diveCountMilestone =>
    l10n.insights_observations_rule_diveCountMilestone,
  ObservationRuleId.diveHoursMilestone =>
    l10n.insights_observations_rule_diveHoursMilestone,
  ObservationRuleId.deepestDive => l10n.insights_observations_rule_deepestDive,
  ObservationRuleId.longestDive => l10n.insights_observations_rule_longestDive,
  ObservationRuleId.newCountry => l10n.insights_observations_rule_newCountry,
  ObservationRuleId.newSpecies => l10n.insights_observations_rule_newSpecies,
  ObservationRuleId.diveGap => l10n.insights_observations_rule_diveGap,
  ObservationRuleId.favouriteSite =>
    l10n.insights_observations_rule_favouriteSite,
  ObservationRuleId.regularBuddy =>
    l10n.insights_observations_rule_regularBuddy,
  ObservationRuleId.busiestMonth =>
    l10n.insights_observations_rule_busiestMonth,
  ObservationRuleId.ascentRate => l10n.insights_observations_rule_ascentRate,
};

/// The observation as one localized sentence in the diver's units. A facts
/// type that does not match its rule (a programming error) falls back to
/// the rule's label rather than throwing in the middle of a list.
String observationSentence(
  Observation o,
  AppLocalizations l10n,
  UnitFormatter units,
) {
  final down = switch (o.facts) {
    TrendFacts(:final direction) => direction == TrendDirection.down,
    _ => false,
  };
  return switch ((o.ruleId, o.facts)) {
    (ObservationRuleId.rmvTrend, final TrendFacts t) =>
      (down
          ? l10n.insights_observations_rmvTrend_improved
          : l10n.insights_observations_rmvTrend_rose)(
        units.formatRmv(t.recent),
        units.formatRmv(t.previous),
        _pct(t),
      ),
    (ObservationRuleId.maxDepthTrend, final TrendFacts t) =>
      (down
          ? l10n.insights_observations_maxDepthTrend_shallower
          : l10n.insights_observations_maxDepthTrend_deeper)(
        units.formatDepth(t.recent),
        units.formatDepth(t.previous),
        _pct(t),
      ),
    (ObservationRuleId.diveTimeTrend, final TrendFacts t) =>
      (down
          ? l10n.insights_observations_diveTimeTrend_shorter
          : l10n.insights_observations_diveTimeTrend_longer)(
        _minutes(l10n, t.recent),
        _minutes(l10n, t.previous),
        _pct(t),
      ),
    (ObservationRuleId.weightTrend, final TrendFacts t) =>
      (down
          ? l10n.insights_observations_weightTrend_less
          : l10n.insights_observations_weightTrend_more)(
        units.formatWeight((t.recent - t.previous).abs()),
      ),
    (ObservationRuleId.frequencyTrend, final TrendFacts t) =>
      (down
          ? l10n.insights_observations_frequencyTrend_fewer
          : l10n.insights_observations_frequencyTrend_more)(
        t.recentDives,
        _pct(t),
      ),
    (ObservationRuleId.diveCountMilestone, final MilestoneFacts m) =>
      (m.includesPrior
          ? l10n.insights_observations_diveCountMilestone
          : l10n.insights_observations_diveCountMilestone_logged)(
        '${m.milestone}',
        units.formatDate(m.date),
      ),
    (ObservationRuleId.diveHoursMilestone, final MilestoneFacts m) =>
      (m.includesPrior
          ? l10n.insights_observations_diveHoursMilestone
          : l10n.insights_observations_diveHoursMilestone_logged)(
        '${m.milestone}',
        units.formatDate(m.date),
      ),
    (ObservationRuleId.deepestDive, final DiveRecordFacts r) =>
      l10n.insights_observations_deepestDive(
        units.formatDepth(r.value),
        units.formatDate(r.date),
        units.formatDepth(r.previousBest),
      ),
    (ObservationRuleId.longestDive, final DiveRecordFacts r) =>
      l10n.insights_observations_longestDive(
        _minutes(l10n, r.value / 60),
        units.formatDate(r.date),
        _minutes(l10n, r.previousBest / 60),
      ),
    (ObservationRuleId.newCountry, final NewCountryFacts c) =>
      l10n.insights_observations_newCountry(
        c.country,
        units.formatDate(c.date),
      ),
    (ObservationRuleId.newSpecies, final NewSpeciesFacts s) =>
      l10n.insights_observations_newSpecies(s.count, s.newestSpeciesName),
    (ObservationRuleId.diveGap, final DiveGapFacts g) =>
      l10n.insights_observations_diveGap(g.days),
    (ObservationRuleId.favouriteSite, final ShareFacts s) =>
      l10n.insights_observations_favouriteSite(
        s.subjectName,
        '${s.dives}',
        '${s.totalDives}',
      ),
    (ObservationRuleId.regularBuddy, final ShareFacts s) =>
      l10n.insights_observations_regularBuddy(
        s.subjectName,
        '${s.dives}',
        '${s.totalDives}',
      ),
    (ObservationRuleId.busiestMonth, final MonthFacts m) =>
      l10n.insights_observations_busiestMonth(
        insightsMonthName(l10n, m.month),
        '${m.years}',
      ),
    (ObservationRuleId.ascentRate, final RateFacts r) =>
      l10n.insights_observations_ascentRate(
        units.formatDepthRate(r.metersPerMin),
        '${r.dives}',
        units.formatDepthRate(
          ObservationThresholds.ascentRateGuidanceLowMPerMin,
          decimals: 0,
        ),
        units.formatDepthRate(
          ObservationThresholds.ascentRateGuidanceHighMPerMin,
          decimals: 0,
        ),
      ),
    (final rule, _) => observationRuleLabel(rule, l10n),
  };
}
