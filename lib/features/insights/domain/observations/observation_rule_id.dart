/// What an observation is about. The declaration order is the ranking tier
/// order (spec section 4.4): safety first, patterns last.
enum ObservationKind { safety, milestone, trend, pattern }

/// The rule that produced an observation. Names are the stored values (the
/// dismissal rows and the muted-rules setting), so a rule is never renamed.
enum ObservationRuleId {
  rmvTrend,
  maxDepthTrend,
  diveTimeTrend,
  weightTrend,
  frequencyTrend,
  diveCountMilestone,
  diveHoursMilestone,
  deepestDive,
  longestDive,
  newCountry,
  newSpecies,
  diveGap,
  favouriteSite,
  regularBuddy,
  busiestMonth,
  ascentRate;

  String get dbValue => name;

  /// Null for a rule this build does not know (written by a newer peer), so
  /// the caller skips it rather than mislabel it.
  static ObservationRuleId? fromDbValue(String value) {
    for (final rule in values) {
      if (rule.name == value) return rule;
    }
    return null;
  }

  ObservationKind get kind => switch (this) {
    ObservationRuleId.ascentRate => ObservationKind.safety,
    ObservationRuleId.diveCountMilestone ||
    ObservationRuleId.diveHoursMilestone ||
    ObservationRuleId.deepestDive ||
    ObservationRuleId.longestDive ||
    ObservationRuleId.newCountry ||
    ObservationRuleId.newSpecies => ObservationKind.milestone,
    ObservationRuleId.rmvTrend ||
    ObservationRuleId.maxDepthTrend ||
    ObservationRuleId.diveTimeTrend ||
    ObservationRuleId.weightTrend ||
    ObservationRuleId.frequencyTrend => ObservationKind.trend,
    ObservationRuleId.diveGap ||
    ObservationRuleId.favouriteSite ||
    ObservationRuleId.regularBuddy ||
    ObservationRuleId.busiestMonth => ObservationKind.pattern,
  };
}
