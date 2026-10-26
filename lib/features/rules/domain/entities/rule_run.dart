import 'package:submersion/features/rules/domain/rule_subject.dart';

/// One field a rule run changed on one dive or site (#3513). [field] is a
/// `BulkField.name`, a `DiveCollection.name`, `notes`, a
/// `SiteRuleField.name`, a `SiteCollection.name` or `description`; [subject]
/// tells the dive and site meanings apart. [before] and [after] are
/// JSON-encodable: a map of column values for a set field, an id list for
/// a membership (dive types in their order, the representative first;
/// buddies as `{id, roles}`; gear as `{id, via?, set?}`; the rest sorted),
/// the full text for an append.
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

  /// The rule that made the change. Kept after that rule is deleted (the
  /// column has no foreign key), so it may name a rule that no longer
  /// exists.
  final String? ruleId;
  final String ruleName;
  final String field;
  final Object? before;
  final Object? after;

  RuleChange copyWith({
    RuleSubject? subject,
    String? targetId,
    String? ruleId,
    String? ruleName,
    String? field,
    Object? before,
    Object? after,
  }) => RuleChange(
    subject: subject ?? this.subject,
    targetId: targetId ?? this.targetId,
    ruleId: ruleId ?? this.ruleId,
    ruleName: ruleName ?? this.ruleName,
    field: field ?? this.field,
    before: before ?? this.before,
    after: after ?? this.after,
  );
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
    this.ruleNames = const [],
  });

  final String id;
  final String? diverId;
  final RuleRunTrigger trigger;

  /// The names of the rules that made the run's changes, as they were named
  /// then; filled by the history list.
  final List<String> ruleNames;
  final String? sourceLabel;
  final String? deviceLabel;
  final DateTime ranAt;

  /// Distinct dives and sites the run changed.
  final int changedCount;
  final DateTime? undoneAt;

  bool get isUndone => undoneAt != null;

  RuleRun copyWith({
    String? sourceLabel,
    String? deviceLabel,
    int? changedCount,
    DateTime? undoneAt,
    List<String>? ruleNames,
  }) => RuleRun(
    id: id,
    diverId: diverId,
    trigger: trigger,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    deviceLabel: deviceLabel ?? this.deviceLabel,
    ranAt: ranAt,
    changedCount: changedCount ?? this.changedCount,
    undoneAt: undoneAt ?? this.undoneAt,
    ruleNames: ruleNames ?? this.ruleNames,
  );
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

  RuleRunRequest copyWith({
    RuleRunTrigger? trigger,
    Map<RuleSubject, Set<String>?>? targets,
    String? sourceLabel,
    List<String>? onlyRuleIds,
  }) => RuleRunRequest(
    diverId: diverId,
    trigger: trigger ?? this.trigger,
    targets: targets ?? this.targets,
    sourceLabel: sourceLabel ?? this.sourceLabel,
    onlyRuleIds: onlyRuleIds ?? this.onlyRuleIds,
  );
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
    this.noRuleSelected = false,
  });

  /// No rule of the diver's would run for the request (none on for it, or
  /// none with its trigger): nothing was looked at.
  static const noRules = RuleRunResult(
    runId: null,
    changes: [],
    changedTargetCount: 0,
    changedCountByRule: {},
    skippedRuleNames: [],
    skippedActionRuleNames: [],
    targetCount: 0,
    outOfScopeCount: 0,
    noRuleSelected: true,
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

  /// See [noRules].
  final bool noRuleSelected;

  bool get changedAnything => changes.isNotEmpty;

  /// This result as recorded in the history under [runId].
  RuleRunResult copyWith({String? runId}) => RuleRunResult(
    runId: runId ?? this.runId,
    changes: changes,
    changedTargetCount: changedTargetCount,
    changedCountByRule: changedCountByRule,
    skippedRuleNames: skippedRuleNames,
    skippedActionRuleNames: skippedActionRuleNames,
    targetCount: targetCount,
    outOfScopeCount: outOfScopeCount,
    noRuleSelected: noRuleSelected,
  );
}
