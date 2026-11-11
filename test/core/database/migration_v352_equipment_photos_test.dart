import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v352 adds `media.observation_id`, the check-in a gear photo backs up, and
/// `equipment.cover_media_id`, the photo chosen to stand for an item (issue
/// #3355). Nullable with no backfill and no foreign key: sync applies media
/// before check-ins, and a peer can delete either end.
void main() {
  test('v352 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(352));
    expect(AppDatabase.migrationVersions, contains(352));
  });

  test('the compatibility floor does not move for nullable columns', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(352));
  });

  Future<Map<String, Object?>> columnOf(
    AppDatabase db,
    String table,
    String name,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.firstWhere((c) => c.read<String>('name') == name).data;
  }

  test('a fresh database has both columns as nullable TEXT', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final observation = await columnOf(db, 'media', 'observation_id');
    expect(observation['type'], 'TEXT');
    expect(observation['notnull'], 0);

    final cover = await columnOf(db, 'equipment', 'cover_media_id');
    expect(cover['type'], 'TEXT');
    expect(cover['notnull'], 0);
  });

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('existing rows upgrade with no check-in and no cover', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        registerAppSqlFunctions(rawDb);
        rawDb.execute('PRAGMA user_version = 351');
        rawDb.execute('''
          CREATE TABLE equipment (
            id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL,
            type TEXT NOT NULL, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)
        ''');
        rawDb.execute('''
          CREATE TABLE media (
            id TEXT NOT NULL PRIMARY KEY, file_type TEXT NOT NULL,
            equipment_id TEXT, created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL)
        ''');
        rawDb.execute(
          "INSERT INTO equipment (id, name, type, created_at, updated_at) "
          "VALUES ('e1', 'Reg', 'regulator', 0, 0)",
        );
        rawDb.execute(
          "INSERT INTO media (id, file_type, equipment_id, created_at, "
          "updated_at) VALUES ('m1', 'photo', 'e1', 0, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final media = await db
        .customSelect("SELECT observation_id FROM media WHERE id = 'm1'")
        .getSingle();
    expect(media.data['observation_id'], isNull);
    final item = await db
        .customSelect("SELECT cover_media_id FROM equipment WHERE id = 'e1'")
        .getSingle();
    expect(item.data['cover_media_id'], isNull);
  });
}
