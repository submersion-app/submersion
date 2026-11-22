import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';
import 'package:submersion/features/rules/presentation/pages/rule_draft.dart';

import '../rules_fixture.dart';

/// The rule editor's draft (issue #4527, phase 4, plan 4).
void main() {
  Rule rule({QueryNode? condition}) => Rule(
    id: 'r1',
    diverId: 'me',
    subject: RuleSubject.dives,
    name: 'Deep',
    enabled: true,
    triggers: const {RuleTrigger.afterImport, RuleTrigger.afterManualCreate},
    condition:
        condition ??
        AndNode([
          depthOver(18),
          TextNode(const ['wreck']),
        ]),
    conditionJson: '',
    actions: const [kAddDeepType, AppendDiveNotesAction('deep')],
    actionsJson: '',
    sortOrder: 0,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  RuleDraft draft({
    String name = 'Deep',
    Set<RuleTrigger> triggers = const {RuleTrigger.afterImport},
    QueryNode? condition,
    bool conditionValid = true,
    bool replacesBrokenCondition = false,
    List<RuleAction> actions = const [kAddDeepType],
  }) => RuleDraft(
    name: name,
    subject: RuleSubject.dives,
    triggers: triggers,
    condition: condition,
    conditionValid: conditionValid,
    replacesBrokenCondition: replacesBrokenCondition,
    actions: actions,
  );

  test('a rule and its own draft are equal however often it is read', () {
    expect(ruleDraftOf(rule()), ruleDraftOf(rule()));
    expect(ruleDraftOf(rule()).hashCode, ruleDraftOf(rule()).hashCode);
  });

  test('triggers compare as sets', () {
    expect(
      draft(triggers: {RuleTrigger.afterImport, RuleTrigger.afterManualCreate}),
      draft(triggers: {RuleTrigger.afterManualCreate, RuleTrigger.afterImport}),
    );
  });

  test('actions in another order are a change', () {
    const notes = AppendDiveNotesAction('deep');
    expect(
      draft(actions: const [kAddDeepType, notes]),
      isNot(draft(actions: const [notes, kAddDeepType])),
    );
  });

  test('a condition that does not parse is a change', () {
    expect(draft(conditionValid: false), isNot(draft()));
  });

  test('a blank draft is a new rule with nothing entered', () {
    expect(blankRuleDraft.name, '');
    expect(blankRuleDraft.subject, RuleSubject.dives);
    expect(blankRuleDraft.triggers, {RuleTrigger.afterImport});
    expect(blankRuleDraft.condition, isNull);
    expect(blankRuleDraft.conditionValid, isTrue);
    expect(blankRuleDraft.actions, isEmpty);
  });

  test('ruleChanges names only what changed', () {
    final changes = ruleChanges(draft(name: 'x'), draft());
    expect(changes.name, 'x');
    expect(changes.triggers, isNull);
    expect(changes.condition, isNull);
    expect(changes.actions, isNull);
  });

  test('ruleChanges carries changed triggers, condition and actions', () {
    const notes = AppendDiveNotesAction('deep');
    final changes = ruleChanges(
      draft(
        triggers: {RuleTrigger.afterManualCreate},
        condition: depthOver(30),
        actions: const [notes],
      ),
      draft(),
    );
    expect(changes.name, isNull);
    expect(changes.triggers, {RuleTrigger.afterManualCreate});
    expect(changes.condition, (node: depthOver(30)));
    expect(changes.actions, const [notes]);
  });

  test('a condition edited over one that did not load is written, even '
      'as no condition', () {
    // The stored condition did not load, so both read as no condition; the
    // diver editing it means "every dive", which replaces what is stored.
    final edited = draft(replacesBrokenCondition: true);
    expect(edited, isNot(draft()));
    expect(ruleChanges(edited, draft()).condition, (node: null));
    expect(ruleChanges(draft(), draft()).condition, isNull);
  });

  test('ruleChanges carries a cleared condition', () {
    final changes = ruleChanges(draft(), draft(condition: depthOver(18)));
    expect(changes.condition, (node: null));
  });
}
