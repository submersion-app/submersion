import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v326: the synced `media_people` table, people tagged on photos and
/// videos (issue #1745). Renumbered from 323 and 324, which #3748 and
/// #3728 took; 325 is #3786's; 319, 321 and 322 are held by PR #3726.
void main() {
  /// A database at [version] with the parents the table references and no
  /// media_people table.
  NativeDatabase setupDb(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      registerAppSqlFunctions(rawDb);
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE buddies (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE media (id TEXT PRIMARY KEY)');
    },
  );

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("PRAGMA index_list('media_people')")
        .get();
    return {for (final r in rows) r.data['name'] as String};
  }

  const columns = <String>[
    'id',
    'media_id',
    'buddy_id',
    'diver_id',
    'bbox_x',
    'bbox_y',
    'bbox_width',
    'bbox_height',
    'video_position_ms',
    'created_at',
    'updated_at',
    'hlc',
  ];

  const indexes = <String>{
    'idx_media_people_media',
    'idx_media_people_buddy',
    'idx_media_people_diver',
  };

  test('v326 is in the ladder and did not move the sync floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(326));
    expect(AppDatabase.migrationVersions, contains(326));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(326));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(326) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(326) + 1,
    );
  });

  test(
    'a v320 database gains media_people with its columns and indexes on open',
    () async {
      final db = AppDatabase(setupDb(320));
      addTearDown(db.close);
      final names = (await tableInfo(db, 'media_people')).map((c) => c['name']);
      expect(names, unorderedEquals(columns));
      expect(await indexNames(db), containsAll(indexes));
    },
  );

  test(
    'the backstop recreates media_people when a parallel branch skipped it',
    () async {
      final db = AppDatabase(setupDb(326));
      addTearDown(db.close);
      final names = (await tableInfo(db, 'media_people')).map((c) => c['name']);
      expect(names, unorderedEquals(columns));
      expect(await indexNames(db), containsAll(indexes));
    },
  );

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb(320));
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);
    expect(
      await tableInfo(upgraded, 'media_people'),
      await tableInfo(fresh, 'media_people'),
    );
    expect(await indexNames(fresh), containsAll(indexes));
  });
}
