import 'package:drift/drift.dart' show Variable;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/core/query/names/name_index.dart';
import 'package:submersion/features/rules/data/repositories/rule_repository.dart';
import 'package:submersion/features/rules/domain/entities/rule.dart';
import 'package:submersion/features/rules/domain/entities/rule_action.dart';
import 'package:submersion/features/rules/domain/rule_subject.dart';

import '../../../helpers/test_database.dart';
import '../rules_fixture.dart';

void main() {
  late AppDatabase db;
  late RuleRepository repo;
  final names = NameIndex(const []);
  const addDeep = DiveMembershipAction(
    DiveCollection.diveTypes,
    MembershipMode.add,
    ['deep'],
  );

  setUp(() async {
    db = await setUpTestDatabase();
    await seedRuleDivers(db, ['me', 'other']);
    repo = RuleRepository();
  });
  tearDown(tearDownTestDatabase);

  Future<String> make(
    String name, {
    String diver = 'me',
    RuleSubject subject = RuleSubject.dives,
    QueryNode? condition,
  }) => repo.create(
    diverId: diver,
    subject: subject,
    name: name,
    triggers: const {RuleTrigger.afterImport},
    condition: condition,
    actions: const [addDeep],
  );

  test('create lists in order with the condition and actions', () async {
    await make('Deep', condition: depthOver(18));
    await make('Boat');
    final all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: names,
    );
    expect(all.map((r) => r.name), ['Deep', 'Boat']);
    expect(all.first.condition, isA<ConditionNode>());
    expect(all.first.actions, const [addDeep]);
    expect(all.first.problem, isNull);
    expect(all.first.isRunnable, isTrue);
    expect(all.last.condition, isNull);
  });

  test('another diver and another subject are not listed', () async {
    await make('Mine');
    await make('Theirs', diver: 'other');
    await make('Site rule', subject: RuleSubject.sites);
    final all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: names,
    );
    expect(all.map((r) => r.name), ['Mine']);
  });

  test('reorder, duplicate, enable and delete', () async {
    final a = await make('A');
    final b = await make('B');
    await repo.reorder([b, a]);
    var all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: names,
    );
    expect(all.map((r) => r.name), ['B', 'A']);

    final copy = await repo.duplicate(a, nameSuffix: ' (copy)');
    await repo.setEnabled(b, false);
    all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: names,
    );
    expect(all.map((r) => r.name), ['B', 'A', 'A (copy)']);
    expect(all.first.enabled, isFalse);
    expect(all.last.id, copy);

    await repo.delete(a);
    final pending = await db
        .customSelect(
          "SELECT COUNT(*) AS n FROM deletion_log WHERE entity_type = 'rules' "
          'AND record_id = ?',
          variables: [Variable<String>(a)],
        )
        .getSingle();
    expect(pending.read<int>('n'), 1);
    expect(await repo.getById(a, names: names), isNull);
  });

  test('a rule naming a missing site loads with unresolvedRef', () async {
    await make(
      'Ghost site',
      condition: ConditionNode(
        FieldPath(['site']),
        QueryOp.eq,
        const RefValue('gone', 'Gone Reef'),
      ),
    );
    final all = await repo.getAll(
      subject: RuleSubject.dives,
      diverId: 'me',
      names: NameIndex.fromRefs({QuerySubject.sites: const []}),
    );
    expect(all.single.problem, RuleLoadProblem.unresolvedRef);
    expect(all.single.isRunnable, isFalse);
  });

  test('actions written by a newer version load with newerVersion', () async {
    final id = await make('Future');
    await db.customStatement(
      "UPDATE rules SET actions_json = '{\"version\":2,\"actions\":[]}' "
      "WHERE id = '$id'",
    );
    final r = await repo.getById(id, names: names);
    expect(r!.problem, RuleLoadProblem.newerVersion);
  });

  test('update rewrites name, triggers, condition and actions', () async {
    final id = await make('Deep');
    final r = (await repo.getById(id, names: names))!;
    await repo.update(
      r.copyWith(
        name: 'Deeper',
        triggers: const {RuleTrigger.afterManualCreate},
        condition: depthOver(30),
        actions: const [AppendDiveNotesAction('deep')],
      ),
    );
    final back = (await repo.getById(id, names: names))!;
    expect(back.name, 'Deeper');
    expect(back.triggers, {RuleTrigger.afterManualCreate});
    expect(back.condition, depthOver(30));
    expect(back.actions, const [AppendDiveNotesAction('deep')]);
  });
}
