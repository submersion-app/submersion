import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v334: equipment_locations gains buddy_id (issue #3790), the buddy a
/// Person place stands for. Every existing place stays as it was, with no
/// link.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE buddies (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL)',
          );
          rawDb.execute(
            'CREATE TABLE equipment_locations ('
            'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
            'name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'other\', '
            'notes TEXT NOT NULL DEFAULT \'\', '
            'is_archived INTEGER NOT NULL DEFAULT 0, '
            'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
            'hlc TEXT${withColumn ? ', buddy_id TEXT' : ''})',
          );
          rawDb.execute(
            'INSERT INTO equipment_locations '
            '(id, name, kind, created_at, updated_at) '
            "VALUES ('anna', 'Anna', 'person', 1, 1)",
          );
        },
      );

  test('v334 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(334));
    expect(AppDatabase.migrationVersions, contains(334));
    expect(
      AppDatabase.migrationStepCount(333),
      AppDatabase.migrationStepCount(334) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(334));
  });

  test('upgrading from v332 leaves every place unlinked, kind kept', () async {
    final db = AppDatabase(dbAt(332));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT kind, buddy_id FROM equipment_locations')
        .getSingle();
    expect(row.read<String>('kind'), 'person');
    expect(row.read<String?>('buddy_id'), isNull);
  });

  test('the link clears, and the place stays, when its buddy goes', () async {
    final db = AppDatabase(dbAt(332));
    addTearDown(db.close);
    final keys = await db
        .customSelect("PRAGMA foreign_key_list('equipment_locations')")
        .get();
    final key = keys.singleWhere((k) => k.read<String>('from') == 'buddy_id');
    expect(key.read<String>('table'), 'buddies');
    expect(key.read<String>('on_delete'), 'SET NULL');
  });

  test('a database already carrying the column is left alone', () async {
    final db = AppDatabase(dbAt(332, withColumn: true));
    addTearDown(db.close);
    final columns =
        (await db
                .customSelect("PRAGMA table_info('equipment_locations')")
                .get())
            .map((c) => c.read<String>('name'))
            .where((n) => n == 'buddy_id');
    expect(columns, hasLength(1));
  });

  test('the backstop restores the column at v334', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT buddy_id FROM equipment_locations')
        .getSingle();
    expect(row.read<String?>('buddy_id'), isNull);
  });
}
