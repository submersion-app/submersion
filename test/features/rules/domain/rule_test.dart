import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../rules_fixture.dart';

Rule _rule({List<RuleAction> actions = const [], RuleLoadProblem? problem}) =>
    Rule(
      id: 'r1',
      diverId: 'me',
      subject: RuleSubject.dives,
      name: 'Deep',
      enabled: true,
      triggers: const {RuleTrigger.afterImport},
      condition: null,
      conditionJson: '',
      actions: actions,
      actionsJson: '',
      sortOrder: 0,
      createdAt: DateTime(2026, 10, 18),
      updatedAt: DateTime(2026, 10, 18),
      problem: problem,
    );

void main() {
  test('a rule with an action and no problem is runnable', () {
    expect(_rule(actions: const [kAddDeepType]).isRunnable, isTrue);
  });

  test('a rule with an unknown action is not runnable', () {
    final r = _rule(
      actions: const [
        kAddDeepType,
        UnknownRuleAction({'kind': 'addTank'}),
      ],
    );
    expect(r.isRunnable, isFalse);
  });

  test('a rule with no actions is not runnable', () {
    expect(_rule().isRunnable, isFalse);
  });

  test('a rule with a load problem is not runnable', () {
    final r = _rule(
      actions: const [kAddDeepType],
      problem: RuleLoadProblem.unresolvedRef,
    );
    expect(r.isRunnable, isFalse);
  });

  test('triggers parse ignoring unknown names', () {
    expect(parseRuleTriggers('afterImport,later'), {RuleTrigger.afterImport});
    expect(parseRuleTriggers(''), isEmpty);
    expect(
      formatRuleTriggers({
        RuleTrigger.afterManualCreate,
        RuleTrigger.afterImport,
      }),
      'afterImport,afterManualCreate',
    );
  });

  test('subjects map to query subjects', () {
    expect(RuleSubject.dives.querySubject, QuerySubject.dives);
    expect(RuleSubject.sites.querySubject, QuerySubject.sites);
  });

  test('copyWith changes only what it names', () {
    final r = _rule(actions: const [kAddDeepType]);
    final c = r.copyWith(name: 'Deeper', enabled: false);
    expect(c.name, 'Deeper');
    expect(c.enabled, isFalse);
    expect(c.actions, r.actions);
    expect(c.id, r.id);
  });
}
