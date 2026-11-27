import 'package:flutter/foundation.dart';

import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

/// The rule editor's form as shown (issue #4527, phase 4): the name as
/// typed, what the rule applies to, when it runs, the condition tree the
/// editor holds and whether its text parses, and the actions in order.
///
/// Compared by value: [QueryNode] and [RuleAction] define `==`, so a change
/// is told from the stored rule without re-encoding either to JSON.
@immutable
class RuleDraft {
  const RuleDraft({
    required this.name,
    required this.subject,
    required this.triggers,
    required this.condition,
    required this.conditionValid,
    this.replacesBrokenCondition = false,
    required this.actions,
  });

  final String name;
  final RuleSubject subject;
  final Set<RuleTrigger> triggers;

  /// Null matches every dive or site.
  final QueryNode? condition;

  /// False while the condition's text does not parse: [condition] is then
  /// the last tree that did, which is not what the diver sees, so the draft
  /// reads as changed.
  final bool conditionValid;

  /// The diver has edited the condition of a rule whose stored condition
  /// did not load. Both read as no condition, so without this a broken
  /// condition cleared to "every dive" would look unchanged and stay
  /// stored.
  final bool replacesBrokenCondition;
  final List<RuleAction> actions;

  @override
  bool operator ==(Object other) =>
      other is RuleDraft &&
      other.name == name &&
      other.subject == subject &&
      setEquals(other.triggers, triggers) &&
      other.condition == condition &&
      other.conditionValid == conditionValid &&
      other.replacesBrokenCondition == replacesBrokenCondition &&
      listEquals(other.actions, actions);

  @override
  int get hashCode => Object.hash(
    name,
    subject,
    Object.hashAllUnordered(triggers),
    condition,
    conditionValid,
    replacesBrokenCondition,
    Object.hashAll(actions),
  );
}

/// The blank form of a new rule: no name, dives, after import, no
/// condition, no actions.
const blankRuleDraft = RuleDraft(
  name: '',
  subject: RuleSubject.dives,
  triggers: {RuleTrigger.afterImport},
  condition: null,
  conditionValid: true,
  actions: [],
);

/// The draft of [rule] as the editor fills its form from it.
RuleDraft ruleDraftOf(Rule rule) => RuleDraft(
  name: rule.name,
  subject: rule.subject,
  triggers: {...rule.triggers},
  condition: rule.condition,
  conditionValid: true,
  actions: [...rule.actions],
);

/// What Save writes on a stored rule: each part whose draft value differs
/// from [start]'s, and the condition once the diver has edited one that did
/// not load. Never the subject, which is fixed once a rule exists.
RuleChanges ruleChanges(RuleDraft draft, RuleDraft start) => (
  name: draft.name == start.name ? null : draft.name,
  triggers: setEquals(draft.triggers, start.triggers) ? null : draft.triggers,
  condition:
      draft.condition == start.condition &&
          draft.replacesBrokenCondition == start.replacesBrokenCondition
      ? null
      : (node: draft.condition),
  actions: listEquals(draft.actions, start.actions) ? null : draft.actions,
);
