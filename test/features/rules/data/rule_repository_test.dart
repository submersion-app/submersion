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
    actions: const [kAddDeepType],
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
    expect(all.first.actions, const [kAddDeepType]);
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

  test('a malformed action is unreadable whatever its message', () async {
    // The error text mentions "newer" by chance; only a newer version may
    // open read-only and keep its stored JSON on save.
    final id = await make('Broken');
    await db.customStatement(
      'UPDATE rules SET actions_json = '
      '\'{"version":1,"actions":[{"kind":"setDiveField","field":["newer"],'
      '"values":{}}]}\' '
      "WHERE id = '$id'",
    );
    final r = await repo.getById(id, names: names);
    expect(r!.problem, RuleLoadProblem.unreadable);
  });

  test('saving keeps what a newer version added', () async {
    // A field this version lacks, inside an action kind it knows, and a
    // trigger it lacks: the rule must not run, and saving it here (say a
    // rename) must not erase them for the device that wrote them.
    final id = await make('Future');
    const future =
        '{"kind":"setDiveField","field":"futureField","values":{"x":1}}';
    await db.customStatement(
      "UPDATE rules SET actions_json = '{\"version\":1,\"actions\":[$future]}', "
      "triggers = 'afterImport,afterSync' WHERE id = '$id'",
    );
    final r = (await repo.getById(id, names: names))!;
    expect(r.isRunnable, isFalse);
    expect(r.actions.single, isA<UnknownRuleAction>());

    await repo.update(r.copyWith(name: 'Renamed'));

    final row = await db
        .customSelect(
          'SELECT actions_json, triggers FROM rules WHERE id = ?',
          variables: [Variable.withString(id)],
        )
        .getSingle();
    expect(row.read<String>('actions_json'), contains('futureField'));
    expect(row.read<String>('triggers'), 'afterImport,afterSync');
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

  group('the editor\'s writes (issue #4527, phase 4)', () {
    Future<RuleRow> row(String id) =>
        (db.select(db.rules)..where((t) => t.id.equals(id))).getSingle();

    test('create writes the rule under the id it is given', () async {
      final id = await repo.create(
        id: 'given-id',
        diverId: 'me',
        subject: RuleSubject.dives,
        name: 'Deep',
        triggers: const {RuleTrigger.afterImport},
        condition: null,
        actions: const [kAddDeepType],
      );
      expect(id, 'given-id');
      expect((await row('given-id')).name, 'Deep');
    });

    test('patch writes only the parts it is given', () async {
      final id = await make('Deep', condition: depthOver(18));
      await repo.setEnabled(id, false);
      final before = await row(id);
      final wrote = await repo.patch(id, (
        name: '  Deeper ',
        triggers: null,
        condition: null,
        actions: null,
      ));
      expect(wrote, isTrue);
      final after = await row(id);
      expect(after.name, 'Deeper');
      expect(after.enabled, isFalse);
      expect(after.triggers, before.triggers);
      expect(after.conditionJson, before.conditionJson);
      expect(after.actionsJson, before.actionsJson);
    });

    test('patch writes each part it is given', () async {
      final id = await make('Deep', condition: depthOver(18));
      await repo.patch(id, (
        name: null,
        triggers: const {RuleTrigger.afterManualCreate},
        condition: (node: depthOver(30)),
        actions: const [AppendDiveNotesAction('deep')],
      ));
      final back = (await repo.getById(id, names: names))!;
      expect(back.name, 'Deep');
      expect(back.triggers, {RuleTrigger.afterManualCreate});
      expect(back.condition, depthOver(30));
      expect(back.actions, const [AppendDiveNotesAction('deep')]);
    });

    test('patch keeps a trigger a newer version added', () async {
      final id = await make('Deep');
      await db.customStatement(
        "UPDATE rules SET triggers = 'afterImport,someFutureTrigger' "
        "WHERE id = '$id'",
      );
      await repo.patch(id, (
        name: null,
        triggers: const {RuleTrigger.afterManualCreate},
        condition: null,
        actions: null,
      ));
      expect((await row(id)).triggers, 'afterManualCreate,someFutureTrigger');
    });

    test('patch can clear the condition', () async {
      final id = await make('Deep', condition: depthOver(18));
      await repo.patch(id, (
        name: null,
        triggers: null,
        condition: (node: null),
        actions: null,
      ));
      expect((await row(id)).conditionJson, encodeRuleCondition(null));
    });

    test('a write to a rule that is gone stamps nothing for sync', () async {
      final id = await make('Deep');
      await repo.delete(id);
      await db.delete(db.syncRecords).go();

      await repo.setEnabled(id, false);
      final wrote = await repo.patch(id, (
        name: 'Back again',
        triggers: null,
        condition: null,
        actions: null,
      ));

      expect(wrote, isFalse);
      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.recordId.equals(id))).get();
      expect(pending, isEmpty);
    });

    test('patch of a rule that is gone writes nothing and says so', () async {
      final id = await make('Deep');
      await repo.delete(id);
      final wrote = await repo.patch(id, (
        name: 'Back again',
        triggers: null,
        condition: null,
        actions: null,
      ));
      expect(wrote, isFalse);
      final rows = await (db.select(
        db.rules,
      )..where((t) => t.id.equals(id))).get();
      expect(rows, isEmpty);
    });
  });
}
