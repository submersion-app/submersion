import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/explore/data/recent_query_repository.dart';
import 'package:submersion/core/query/domain/query_node.dart';

/// v19: recent searches gain a kind, typed or asked (#2773). Rows the v18
/// table held were all asked sentences and must survive the upgrade.
void main() {
  test('upgrade from a stored v18 schema keeps the asked rows', () async {
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE recent_queries ('
              'diver_id TEXT NOT NULL, key TEXT NOT NULL, '
              'sentence TEXT NOT NULL, locale TEXT NOT NULL, '
              'parsed_json TEXT NOT NULL, schema_version INTEGER NOT NULL, '
              'subject TEXT NOT NULL, last_used_at INTEGER NOT NULL, '
              'PRIMARY KEY (diver_id, locale, key))',
            )
            ..execute(
              "INSERT INTO recent_queries VALUES ('ana', 'turtles', "
              "'turtles', 'en', '{}', 4, 'dives', 1753600000000)",
            )
            ..execute('PRAGMA user_version = 18');
        },
      ),
    );
    addTearDown(db.close);
    final row = await db.select(db.recentQueries).getSingle();
    expect(row.sentence, 'turtles');
    expect(row.kind, 'asked');
  });

  test('a fresh database takes typed rows', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    LocalCacheDatabaseService.instance.setTestDatabase(db);
    addTearDown(() async {
      await db.close();
      LocalCacheDatabaseService.instance.resetForTesting();
    });
    expect(db.schemaVersion, greaterThanOrEqualTo(19));
    await RecentQueryRepository().recordTyped(
      'manta',
      TextNode(['manta']),
      locale: 'en',
      diverId: 'ana',
    );
    final row = await db.select(db.recentQueries).getSingle();
    expect(row.kind, 'typed');
  });

  test('a v19 table without the kind is healed on open', () async {
    // A colliding branch's v19 that created the table without the column:
    // no rung runs, so the open must add it.
    final db = LocalCacheDatabase(
      NativeDatabase.memory(
        setup: (raw) {
          raw
            ..execute(
              'CREATE TABLE recent_queries ('
              'diver_id TEXT NOT NULL, key TEXT NOT NULL, '
              'sentence TEXT NOT NULL, locale TEXT NOT NULL, '
              'parsed_json TEXT NOT NULL, schema_version INTEGER NOT NULL, '
              'subject TEXT NOT NULL, last_used_at INTEGER NOT NULL, '
              'PRIMARY KEY (diver_id, locale, key))',
            )
            ..execute(
              "INSERT INTO recent_queries VALUES ('ana', 'turtles', "
              "'turtles', 'en', '{}', 4, 'dives', 1753600000000)",
            )
            ..execute('PRAGMA user_version = 19');
        },
      ),
    );
    addTearDown(db.close);
    final row = await db.select(db.recentQueries).getSingle();
    expect(row.kind, 'asked');
  });
}
