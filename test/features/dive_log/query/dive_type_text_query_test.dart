import 'package:drift/drift.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// A bare search word matches a dive's dive type (issue #2884): the stored
/// name of a built-in or custom type, and a built-in's translated name in
/// any app language.
void main() {
  late AppDatabase db;
  final dives = appQueryRegistry.entityFor(QuerySubject.dives);

  Future<void> dive(String id, List<String> typeIds) async {
    const now = 1735689600000;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion.insert(
            id: id,
            diverId: const Value('me'),
            diveDateTime: now,
            createdAt: now,
            updatedAt: now,
          ),
        );
    for (final typeId in typeIds) {
      await db.customStatement(
        'INSERT INTO dive_dive_types (id, dive_id, dive_type_id, created_at) '
        'VALUES (?, ?, ?, ?)',
        ['$id-$typeId', id, typeId, now],
      );
    }
  }

  Future<void> customType(String id, String name) => db.customStatement(
    'INSERT INTO dive_types '
    '(id, name, is_built_in, sort_order, created_at, updated_at) '
    'VALUES (?, ?, 0, 99, 0, 0)',
    [id, name],
  );

  /// The ids a free-text search for [words] (one term) returns.
  Future<Set<String>> search(String words) async {
    final q = compileQuery(
      TextNode([words]),
      dives,
      appQueryRegistry,
      rootAlias: 'd',
    );
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: q.params.map((p) => Variable(p)).toList(),
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: 0,
            updatedAt: 0,
          ),
        );
    await customType('muck-1', 'Muck Dive');
    await dive('iceDive', ['ice']);
    await dive('wreckNight', ['wreck', 'night']);
    await dive('muckDive', ['muck-1']);
    await dive('reefDive', ['recreational']);
  });
  tearDown(tearDownTestDatabase);

  test('matches a built-in type by its stored English name', () async {
    expect(await search('ice'), {'iceDive'});
    expect(await search('ICE'), {'iceDive'});
    expect(await search('night'), {'wreckNight'});
  });

  test('matches a built-in type by a translated name', () async {
    expect(await search('Eis'), {'iceDive'}, reason: 'German short name');
    expect(await search('glace'), {'iceDive'}, reason: 'French');
    expect(await search('Wracktauchen'), {'wreckNight'});
    expect(await search('épave'), {'wreckNight'}, reason: 'non-ASCII case');
  });

  test('matches a custom type by its own name', () async {
    expect(await search('muck'), {'muckDive'});
  });

  test('a term naming no type matches no dive through the type', () async {
    expect(await search('zzznope'), isEmpty);
  });

  test('the compiled query reads the dive type tables', () {
    final q = compileQuery(TextNode(['ice']), dives, appQueryRegistry);
    expect(q.tablesTouched, containsAll(['dive_dive_types', 'dive_types']));
  });

  test('a custom type holding a built-in slug keeps its own name', () async {
    // A database predating the v93 seed can hold a diver-created row on
    // slug `wreck` (is_built_in = 0); its label is the diver's, so the
    // built-in translations ("Wrack", "Épave") must not reach it.
    await db.customStatement(
      "UPDATE dive_types SET name = 'Old Hulls', is_built_in = 0 "
      "WHERE id = 'wreck'",
    );
    expect(await search('Wrack'), isEmpty);
    expect(await search('hulls'), {'wreckNight'});
  });

  test('a junction row whose type row has not synced yet still matches a '
      'built-in slug', () async {
    await db.customStatement("DELETE FROM dive_types WHERE id = 'ice'");
    expect(await search('Eis'), {'iceDive'});
  });
}
