import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/query/compiler/query_compiler.dart';
import 'package:submersion/features/dive_sites/query/site_query_entity.dart';
import 'package:submersion/features/query/app_query_registry.dart';
import 'package:submersion/features/query/data/query_id_set_runner.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  const now = 1735689600000;

  setUp(() async {
    db = await setUpTestDatabase();
    await db
        .into(db.divers)
        .insert(
          DiversCompanion.insert(
            id: 'me',
            name: 'me',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'a',
            name: 'a',
            diverId: const Value('me'),
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion.insert(
            id: 'b',
            name: 'b',
            createdAt: now,
            updatedAt: now,
          ),
        );
  });
  tearDown(tearDownTestDatabase);

  test('ids runs the compiled query and ANDs a scope', () async {
    final runner = QueryIdSetRunner(db);
    final all = compileQuery(null, siteQueryEntity, appQueryRegistry);
    expect(await runner.ids(all), {'a', 'b'});
    expect(
      await runner.ids(all, scope: (sql: 'r0.diver_id = ?', params: ['me'])),
      {'a'},
    );
  });

  test('watchTables ticks on a write to a named table', () async {
    final runner = QueryIdSetRunner(db);
    var ticks = 0;
    final sub = runner.watchTables({'site_tags'}).listen((_) => ticks++);
    addTearDown(sub.cancel);
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 't',
            name: 't',
            createdAt: now,
            updatedAt: now,
          ),
        );
    await db
        .into(db.siteTags)
        .insert(
          SiteTagsCompanion.insert(
            id: 'st',
            siteId: 'a',
            tagId: 't',
            createdAt: now,
          ),
        );
    await Future<void>.delayed(const Duration(milliseconds: 400));
    expect(ticks, greaterThan(0));
  });
}
