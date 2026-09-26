import 'dart:convert';

import 'package:drift/drift.dart' hide isNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/domain/query_json.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/data/repositories/saved_query_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late SavedQueryRepository repo;
  final node = ConditionNode(
    FieldPath(['depth']),
    QueryOp.gt,
    const NumberValue(30, null),
  );

  setUp(() async {
    db = await setUpTestDatabase();
    final now = DateTime(2026, 9, 26).millisecondsSinceEpoch;
    for (final id in ['me', 'other']) {
      await db
          .into(db.divers)
          .insert(
            DiversCompanion.insert(
              id: id,
              name: id,
              createdAt: now,
              updatedAt: now,
            ),
          );
    }
    repo = SavedQueryRepository();
  });
  tearDown(tearDownTestDatabase);

  QueryNode decode(String json) =>
      queryNodeFromJson(jsonDecode(json) as Map<String, Object?>);

  test('create stores the versioned JSON and stamps sync state', () async {
    final saved = await repo.create(
      subject: QuerySubject.dives,
      name: ' Deep ',
      node: node,
      diverId: 'me',
    );
    expect(saved.name, 'Deep');
    expect(saved.subject, 'dives');
    expect(saved.diverId, 'me');
    expect(decode(saved.queryJson), node);
    final pending = await db
        .customSelect(
          "SELECT 1 FROM sync_records WHERE entity_type = 'savedQueries' "
          'AND record_id = ?',
          variables: [Variable<String>(saved.id)],
        )
        .get();
    expect(pending, isNotEmpty);
  });

  test('getAll is scoped to the diver plus unowned rows, ordered', () async {
    final a = await repo.create(
      subject: QuerySubject.dives,
      name: 'B',
      node: node,
      diverId: 'me',
    );
    final b = await repo.create(
      subject: QuerySubject.dives,
      name: 'A',
      node: node,
      diverId: 'me',
    );
    await repo.create(
      subject: QuerySubject.dives,
      name: 'Theirs',
      node: node,
      diverId: 'other',
    );
    await repo.create(
      subject: QuerySubject.sites,
      name: 'Sites',
      node: node,
      diverId: 'me',
    );
    // Creation order is sort order, whatever the names say.
    final mine = await repo.getAll(subject: 'dives', diverId: 'me');
    expect(mine.map((q) => q.name), ['B', 'A']);
    await repo.reorder([b.id, a.id]);
    expect(
      (await repo.getAll(subject: 'dives', diverId: 'me')).map((q) => q.name),
      ['A', 'B'],
    );
    expect(
      (await repo.getAll(diverId: 'me')).map((q) => q.subject),
      containsAll(['dives', 'sites']),
    );
  });

  test('rename, updateQuery and delete', () async {
    final saved = await repo.create(
      subject: QuerySubject.dives,
      name: 'Deep',
      node: node,
      diverId: 'me',
    );
    await repo.rename(saved.id, 'Deeper');
    expect((await repo.getById(saved.id))!.name, 'Deeper');
    final other = ConditionNode(FieldPath(['weights']), QueryOp.isEmpty, null);
    await repo.updateQuery(saved.id, other);
    expect(decode((await repo.getById(saved.id))!.queryJson), other);
    await repo.delete(saved.id);
    expect(await repo.getById(saved.id), isNull);
    final tomb = await db
        .customSelect(
          "SELECT 1 FROM deletion_log WHERE entity_type = 'savedQueries' "
          'AND record_id = ?',
          variables: [Variable<String>(saved.id)],
        )
        .get();
    expect(tomb, isNotEmpty);
  });

  test('the tick fires on a write', () async {
    var fired = false;
    final sub = repo.watchSavedQueriesChanges().listen((_) => fired = true);
    addTearDown(sub.cancel);
    await repo.create(
      subject: QuerySubject.dives,
      name: 'x',
      node: node,
      diverId: 'me',
    );
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(fired, isTrue);
  });

  test('reorder leaves rows no diver owns alone; new rows land last', () async {
    final now = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.savedQueries)
        .insert(
          SavedQueriesCompanion.insert(
            id: 'shared',
            subject: 'dives',
            name: 'Shared',
            queryJson: '{}',
            sortOrder: const Value(5),
            createdAt: now,
            updatedAt: now,
          ),
        );
    final a = await repo.create(
      subject: QuerySubject.dives,
      name: 'A',
      node: node,
      diverId: 'me',
    );
    // Unowned rows list after the diver's own, so numbering is per diver.
    expect(a.sortOrder, 0);
    final b = await repo.create(
      subject: QuerySubject.dives,
      name: 'B',
      node: node,
      diverId: 'me',
    );
    await repo.reorder([b.id, 'shared', a.id]);
    final shared = await repo.getById('shared');
    expect(shared!.sortOrder, 5);
    final pending = await db
        .customSelect("SELECT 1 FROM sync_records WHERE record_id = 'shared'")
        .get();
    expect(pending, isEmpty);
    expect((await repo.getById(b.id))!.sortOrder, 0);
    expect((await repo.getById(a.id))!.sortOrder, 1);
  });

  test(
    'a drag orders the diver\'s rows exactly; unowned rows list after',
    () async {
      final now = DateTime(2026).millisecondsSinceEpoch;
      // Sorts first by both sort_order and name, so only the owned-first
      // rule keeps it from tying with the diver's dragged rows.
      await db
          .into(db.savedQueries)
          .insert(
            SavedQueriesCompanion.insert(
              id: 'shared',
              subject: 'dives',
              name: 'Aaa shared',
              queryJson: '{}',
              sortOrder: const Value(0),
              createdAt: now,
              updatedAt: now,
            ),
          );
      final a = await repo.create(
        subject: QuerySubject.dives,
        name: 'A',
        node: node,
        diverId: 'me',
      );
      final b = await repo.create(
        subject: QuerySubject.dives,
        name: 'B',
        node: node,
        diverId: 'me',
      );
      await repo.reorder([b.id, 'shared', a.id]);
      final names = (await repo.getAll(
        subject: 'dives',
        diverId: 'me',
      )).map((q) => q.name);
      expect(names, ['B', 'A', 'Aaa shared']);
    },
  );
}
