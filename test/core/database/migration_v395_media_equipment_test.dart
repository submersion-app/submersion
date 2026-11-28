import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v395: the synced `media_equipment` table, gear items linked to
/// photos and videos (issue #5046).
void main() {
  /// A database at [version] with the parents the table references and no
  /// media_equipment table.
  NativeDatabase setupDb(int version) => NativeDatabase.memory(
    setup: (rawDb) {
      registerAppSqlFunctions(rawDb);
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute('CREATE TABLE media (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE equipment (id TEXT PRIMARY KEY)');
    },
  );

  Future<List<Map<String, Object?>>> tableInfo(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('media_equipment')")
        .get();
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
        .customSelect("PRAGMA index_list('media_equipment')")
        .get();
    return {for (final r in rows) r.data['name'] as String};
  }

  /// The column lists of the table's unique indexes.
  Future<Set<String>> uniqueIndexColumns(AppDatabase db) async {
    final rows = await db
        .customSelect("PRAGMA index_list('media_equipment')")
        .get();
    final result = <String>{};
    for (final r in rows) {
      if (r.data['unique'] != 1) continue;
      final cols = await db
          .customSelect("PRAGMA index_info('${r.data['name']}')")
          .get();
      result.add([for (final c in cols) c.data['name'] as String].join(','));
    }
    return result;
  }

  const columns = <String>[
    'id',
    'media_id',
    'equipment_id',
    'created_at',
    'hlc',
  ];

  test('v395 is in the ladder and did not move the sync floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(395));
    expect(AppDatabase.migrationVersions, contains(395));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(395));
    const versions = AppDatabase.migrationVersions;
    final below = versions[versions.indexOf(395) - 1];
    expect(
      AppDatabase.migrationStepCount(below),
      AppDatabase.migrationStepCount(395) + 1,
    );
  });

  test('upgrading a v394 database creates media_equipment with its unique pair '
      'and equipment index', () async {
    final db = AppDatabase(setupDb(394));
    addTearDown(db.close);
    final names = (await tableInfo(db)).map((c) => c['name']);
    expect(names, unorderedEquals(columns));
    expect(await indexNames(db), contains('idx_media_equipment_equipment'));
    expect(await uniqueIndexColumns(db), contains('media_id,equipment_id'));
  });

  test('the backstop recreates a dropped media_equipment', () async {
    final db = AppDatabase(setupDb(395));
    addTearDown(db.close);
    final names = (await tableInfo(db)).map((c) => c['name']);
    expect(names, unorderedEquals(columns));
    expect(await indexNames(db), contains('idx_media_equipment_equipment'));
  });

  test('a fresh database matches an upgraded one', () async {
    final upgraded = AppDatabase(setupDb(394));
    addTearDown(upgraded.close);
    final fresh = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(fresh.close);
    expect(await tableInfo(upgraded), await tableInfo(fresh));
    expect(await indexNames(fresh), contains('idx_media_equipment_equipment'));
    expect(await uniqueIndexColumns(fresh), contains('media_id,equipment_id'));
  });

  test('inserting the same pair twice fails on the unique key', () async {
    final db = AppDatabase(setupDb(394));
    addTearDown(db.close);
    await db.customStatement("INSERT INTO media (id) VALUES ('m1')");
    await db.customStatement("INSERT INTO equipment (id) VALUES ('e1')");
    await db.customStatement(
      'INSERT INTO media_equipment (id, media_id, equipment_id, created_at) '
      "VALUES ('l1', 'm1', 'e1', 1)",
    );
    expect(
      () => db.customStatement(
        'INSERT INTO media_equipment (id, media_id, equipment_id, created_at) '
        "VALUES ('l2', 'm1', 'e1', 2)",
      ),
      throwsA(isA<Exception>()),
    );
  });
}
