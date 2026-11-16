import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// A search typed without accents finds the accented name (#4498): nobody
/// remembers months later whether a buddy was saved as "Jérémie" or
/// "Jeremie". Search folds accents; an exact `=` still does not, because it
/// asks for that spelling.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO buddies (id, diver_id, name, created_at, updated_at) "
      "VALUES ('b1', 'me', 'Jérémie Dupont', 1000, 1000), "
      "('b2', 'me', 'Joachim', 1000, 1000), "
      "('b3', 'me', 'Łukasz Straße', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dive_sites (id, name, country, created_at, updated_at) "
      "VALUES ('s1', 'Épave du Lac', 'Égypte', 1000, 1000)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, site_id, notes, dive_date_time, "
      "created_at, updated_at) "
      "VALUES ('d1', 'me', 's1', 'Écueil au nord', 1000, 1000, 1000)",
    );
  });
  tearDown(tearDownTestDatabase);

  Future<Set<String>> ids(
    QuerySubject subject,
    String table,
    QueryNode node,
  ) async {
    final entity = appQueryRegistry.entityFor(subject);
    final q = compileQuery(node, entity, appQueryRegistry, rootAlias: 'r');
    final rows = await db
        .customSelect(
          'SELECT r.id FROM $table r WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  Future<Set<String>> buddies(QueryNode node) =>
      ids(QuerySubject.buddies, 'buddies', node);
  Future<Set<String>> dives(QueryNode node) =>
      ids(QuerySubject.dives, 'dives', node);

  ConditionNode cond(List<String> path, QueryOp op, QueryValue value) =>
      ConditionNode(FieldPath(path), op, value);

  for (final spelling in ['jeremie', 'JEREMIE', 'Jérémie', 'jérémie']) {
    test('a bare word "$spelling" finds Jérémie', () async {
      expect(await buddies(TextNode([spelling])), {'b1'});
    });

    test('name contains "$spelling" finds Jérémie', () async {
      expect(
        await buddies(cond(['name'], QueryOp.contains, StringValue(spelling))),
        {'b1'},
      );
    });
  }

  test('a phrase folds every word', () async {
    expect(await buddies(TextNode(['jeremie', 'dupont'])), {'b1'});
  });

  test('letters beyond Latin-1 fold too', () async {
    expect(await buddies(TextNode(['lukasz'])), {'b3'});
    expect(await buddies(TextNode(['strasse'])), {'b3'});
  });

  test('a bare word reaches the site through the relation', () async {
    expect(await dives(TextNode(['epave'])), {'d1'});
    expect(await dives(TextNode(['ecueil'])), {'d1'});
  });

  test('an exact match still asks for the accents', () async {
    expect(
      await dives(
        cond(['site', 'country'], QueryOp.eq, const StringValue('egypte')),
      ),
      isEmpty,
    );
    expect(
      await dives(
        cond(['site', 'country'], QueryOp.eq, const StringValue('ÉGYPTE')),
      ),
      {'d1'},
    );
  });
}
