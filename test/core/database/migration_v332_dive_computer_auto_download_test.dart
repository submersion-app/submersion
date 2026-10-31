import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v332: dive_computers gains auto_download_disabled (issue #3361),
/// the per-device opt-out from the passive auto-connect scan. Every
/// existing computer stays included in auto-download.
void main() {
  NativeDatabase dbAt(
    int version, {
    bool withColumn = false,
  }) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE dive_computers ('
        'id TEXT NOT NULL PRIMARY KEY, diver_id TEXT, '
        'name TEXT NOT NULL, dive_count INTEGER NOT NULL DEFAULT 0, '
        'is_favorite INTEGER NOT NULL DEFAULT 0, '
        "notes TEXT NOT NULL DEFAULT '', "
        'created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, '
        'hlc TEXT${withColumn ? ', auto_download_disabled INTEGER NOT NULL DEFAULT 0' : ''})',
      );
      rawDb.execute(
        'INSERT INTO dive_computers (id, name, created_at, updated_at) '
        "VALUES ('c1', 'My Perdix', 1, 1)",
      );
    },
  );

  test('v332 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(332));
    expect(AppDatabase.migrationVersions, contains(332));
    expect(
      AppDatabase.migrationStepCount(331),
      AppDatabase.migrationStepCount(332) + 1,
    );
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(332));
  });

  test(
    'upgrading from v331 leaves every computer included in auto-download',
    () async {
      final db = AppDatabase(dbAt(331));
      addTearDown(db.close);
      final row = await db
          .customSelect(
            'SELECT name, auto_download_disabled FROM dive_computers',
          )
          .getSingle();
      expect(row.read<String>('name'), 'My Perdix');
      expect(row.read<bool>('auto_download_disabled'), isFalse);
    },
  );

  test('a database already carrying the column is left alone', () async {
    final db = AppDatabase(dbAt(331, withColumn: true));
    addTearDown(db.close);
    final columns =
        (await db.customSelect("PRAGMA table_info('dive_computers')").get())
            .map((c) => c.read<String>('name'))
            .where((n) => n == 'auto_download_disabled');
    expect(columns, hasLength(1));
  });

  test('the backstop restores the column at v332', () async {
    final db = AppDatabase(dbAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    final row = await db
        .customSelect('SELECT auto_download_disabled FROM dive_computers')
        .getSingle();
    expect(row.read<bool>('auto_download_disabled'), isFalse);
  });
}
