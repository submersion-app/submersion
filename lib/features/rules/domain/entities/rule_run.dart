import 'package:submersion/features/rules/domain/rule_subject.dart';

/// One field a rule run changed on one dive or site (#3513). [field] is a
/// `BulkField.name`, a `DiveCollection.name`, `notes`, a
/// `SiteRuleField.name`, a `SiteCollection.name` or `description`; [subject]
/// tells the dive and site meanings apart. [before] and [after] are
/// JSON-encodable: a map of column values for a set field, a sorted id list
/// (buddies: `{id, role}` maps) for a membership, the full text for an
/// append.
class RuleChange {
  const RuleChange({
    required this.subject,
    required this.targetId,
    required this.ruleId,
    required this.ruleName,
    required this.field,
    required this.before,
    required this.after,
  });

  final RuleSubject subject;
  final String targetId;

  /// Null once the rule that made the change is deleted.
  final String? ruleId;
  final String ruleName;
  final String field;
  final Object? before;
  final Object? after;
}

/// One history entry: a run of the rules that changed something.
class RuleRun {
  const RuleRun({
    required this.id,
    required this.diverId,
    required this.trigger,
    required this.sourceLabel,
    required this.deviceLabel,
    required this.ranAt,
    required this.changedCount,
    required this.undoneAt,
  });

  final String id;
  final String? diverId;
  final RuleRunTrigger trigger;
  final String? sourceLabel;
  final String? deviceLabel;
  final DateTime ranAt;

  /// Distinct dives and sites the run changed.
  final int changedCount;
  final DateTime? undoneAt;

  bool get isUndone => undoneAt != null;
}

/// What to run the rules on (#3513). A null target set for a subject means
/// every dive or site the diver's rules may change; a subject missing from
/// [targets] is not run. [onlyRuleIds] narrows the run to those rules,
/// enabled or not ("Run on all" from a rule's row). Automatic triggers run
/// only the rules that chose them; on-demand runs ignore trigger choices.
class RuleRunRequest {
  const RuleRunRequest({
    required this.diverId,
    required this.trigger,
    required this.targets,
    this.sourceLabel,
    this.onlyRuleIds,
  });

  final String diverId;
  final RuleRunTrigger trigger;
  final Map<RuleSubject, Set<String>?> targets;
  final String? sourceLabel;
  final List<String>? onlyRuleIds;
}

/// What a run (or its preview) did.
class RuleRunResult {
  const RuleRunResult({
    required this.runId,
    required this.changes,
    required this.changedTargetCount,
    required this.changedCountByRule,
    required this.skippedRuleNames,
    required this.skippedActionRuleNames,
    required this.targetCount,
    required this.outOfScopeCount,
    required this.ruleCount,
  });

  static const empty = RuleRunResult(
    runId: null,
    changes: [],
    changedTargetCount: 0,
    changedCountByRule: {},
    skippedRuleNames: [],
    skippedActionRuleNames: [],
    targetCount: 0,
    outOfScopeCount: 0,
    ruleCount: 0,
  );

  /// The history entry, or null for a preview or a run that changed
  /// nothing.
  final String? runId;
  final List<RuleChange> changes;

  /// Distinct dives and sites changed.
  final int changedTargetCount;

  /// Distinct targets each rule changed, by rule name.
  final Map<String, int> changedCountByRule;

  /// Rules that could not run (a condition that no longer loads, an action
  /// from a newer version).
  final List<String> skippedRuleNames;

  /// Rules that ran but skipped an action naming something deleted.
  final List<String> skippedActionRuleNames;

  /// Eligible targets the run considered.
  final int targetCount;

  /// Requested targets left out because the diver may not change them (a
  /// library site, another profile's site, an unlogged plan).
  final int outOfScopeCount;

  /// Rules that ran.
  final int ruleCount;

  bool get changedAnything => changes.isNotEmpty;
}
