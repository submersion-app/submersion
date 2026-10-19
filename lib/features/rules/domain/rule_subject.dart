import 'package:submersion/core/query/domain/query_subject.dart';

/// What a logbook rule applies to (#3513). Fixed once the rule exists: its
/// condition and actions are written for one subject.
enum RuleSubject {
  dives,
  sites;

  QuerySubject get querySubject => switch (this) {
    RuleSubject.dives => QuerySubject.dives,
    RuleSubject.sites => QuerySubject.sites,
  };
}

/// When a rule runs on its own. Running on demand is always possible and is
/// not a trigger.
enum RuleTrigger { afterImport, afterManualCreate }

/// What started one run of the rules, as the history shows it.
enum RuleRunTrigger { imported, createdByHand, onDemandAll, onDemandSelection }

/// Reads the stored comma-joined trigger names, dropping any this version
/// does not know (a newer app may add triggers).
Set<RuleTrigger> parseRuleTriggers(String stored) => {
  for (final name in stored.split(','))
    for (final t in RuleTrigger.values)
      if (t.name == name.trim()) t,
};

/// The stored form of [triggers], in declaration order so equal sets store
/// equal strings.
String formatRuleTriggers(Set<RuleTrigger> triggers) => [
  for (final t in RuleTrigger.values)
    if (triggers.contains(t)) t.name,
].join(',');
