import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v331: equipment_locations gains dive_center_id (issue #3623), the
/// saved center a Dive center place stands for. Every existing place stays
/// as it was, with no link.
void main() {
  NativeDatabase dbAt(int version, {bool withColumn = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          rawDb.execute(
            'CREATE TABLE dive_centers (id TEXT NOT NULL PRIMARY KEY, '
            'name TEXT NOT NULL)',
          );
          rawDb.execute(
            'CREATE TABLE equipment_locations ('
            'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
            'name TEXT NOT NULL, kind TEXT NOT NULL DEFAULT \'other\', '
            'notes TEXT NOT NULL DEFAULT \'\', '
            'is_archived INTEGER NOT NULL DEFAULT 0, '
            'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
            'hlc TEXT${withColumn ? ', dive_center_id TEXT' : ''})',
          );
          rawDb.execute(
            'INSERT INTO equipment_locations '
            '(id, name, kind, created_at, updated_at) '
            "VALUES ('shop', 'Joe''s Scuba', 'serviceShop', 1, 1)",
          );
        },
      );

  test('v331 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(331));
    expect(AppDatabase.migrationVersions, contains(331));
    expect(
      AppDatabase.migrationStepCount(330),
      AppDatabase.migrationStepCount(331) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(331));
  });

  test('upgrading from v330 leaves every place unlinked, kind kept', () async {
    final db = AppDatabase(dbAt(330));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT kind, dive_center_id FROM equipment_locations')
        .getSingle();
    expect(row.read<String>('kind'), 'serviceShop');
    expect(row.read<String?>('dive_center_id'), isNull);
  });

  test('the link clears, and the place stays, when its center goes', () async {
    final db = AppDatabase(dbAt(330));
    addTearDown(db.close);
    final keys = await db
        .customSelect("PRAGMA foreign_key_list('equipment_locations')")
        .get();
    final key = keys.singleWhere(
      (k) => k.read<String>('from') == 'dive_center_id',
    );
    expect(key.read<String>('table'), 'dive_centers');
    expect(key.read<String>('on_delete'), 'SET NULL');
  });

  test('a database already carrying the column is left alone', () async {
    final db = AppDatabase(dbAt(330, withColumn: true));
    addTearDown(db.close);
    final columns =
        (await db
                .customSelect("PRAGMA table_info('equipment_locations')")
                .get())
            .map((c) => c.read<String>('name'))
            .where((n) => n == 'dive_center_id');
    expect(columns, hasLength(1));
  });

  test('the backstop restores the column at v331', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT dive_center_id FROM equipment_locations')
        .getSingle();
    expect(row.read<String?>('dive_center_id'), isNull);
  });
}
