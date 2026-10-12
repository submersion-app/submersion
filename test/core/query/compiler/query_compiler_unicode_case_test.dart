import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/core/query/domain/query_node.dart';
import 'package:submersion/core/query/domain/query_subject.dart';
import 'package:submersion/features/query/app_query_registry.dart';

import '../../../helpers/test_database.dart';

/// Text matching in the query language folds case for every script, not
/// just ASCII (#3032): SQLite's LOWER() and LIKE both leave "É" alone, so a
/// query typed in a different case from the stored accented capital missed.
void main() {
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'Me', 1000, 1000)",
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

  final dives = appQueryRegistry.entityFor(QuerySubject.dives);

  Future<Set<String>> ids(QueryNode node) async {
    final q = compileQuery(node, dives, appQueryRegistry, rootAlias: 'd');
    final rows = await db
        .customSelect(
          'SELECT d.id FROM dives d WHERE ${q.where}',
          variables: [for (final p in q.params) Variable(p)],
        )
        .get();
    return rows.map((r) => r.read<String>('id')).toSet();
  }

  ConditionNode cond(List<String> path, QueryOp op, QueryValue value) =>
      ConditionNode(FieldPath(path), op, value);

  for (final spelling in ['écueil', 'ÉCUEIL', 'Écueil']) {
    test('a bare word "$spelling" finds the notes', () async {
      expect(await ids(TextNode([spelling])), {'d1'});
    });

    test('notes contains "$spelling"', () async {
      expect(
        await ids(cond(['notes'], QueryOp.contains, StringValue(spelling))),
        {'d1'},
      );
    });
  }

  test('a bare word reaches the site name through the relation', () async {
    expect(await ids(TextNode(['épave'])), {'d1'});
  });

  for (final spelling in ['égypte', 'ÉGYPTE']) {
    test('site.country = "$spelling"', () async {
      expect(
        await ids(cond(['site', 'country'], QueryOp.eq, StringValue(spelling))),
        {'d1'},
      );
      expect(
        await ids(
          cond(['site', 'country'], QueryOp.neq, StringValue(spelling)),
        ),
        isEmpty,
      );
    });

    test('site.country in ["$spelling"]', () async {
      expect(
        await ids(
          cond(
            ['site', 'country'],
            QueryOp.inList,
            ListValue([StringValue(spelling)]),
          ),
        ),
        {'d1'},
      );
    });
  }
}
