import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v360: diver_settings.show_country_flags, the switch for the flags
/// beside site locations and trips (issue #4426). Defaulted on, no backfill,
/// so every existing diver keeps seeing flags and the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool? stored}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${stored != null ? ', show_country_flags INTEGER NOT NULL DEFAULT 1' : ''})",
      );
      rawDb.execute(
        stored != null
            ? 'INSERT INTO diver_settings (id, diver_id, show_country_flags) '
                  "VALUES ('s1', 'd1', ${stored ? 1 : 0})"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  Future<int> storedValue(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT show_country_flags AS v FROM diver_settings',
              )
              .getSingle())
          .read<int>('v');

  test('v360 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(360));
    expect(AppDatabase.migrationVersions, contains(360));
  });

  test('the new column is defaulted and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(360));
  });

  test('upgrading from v359 adds the column switched on', () async {
    final db = AppDatabase(dbAt(359));
    addTearDown(db.close);
    expect(await storedValue(db), 1);
  });

  test('the upgraded column is a boolean, as on a fresh install', () async {
    final db = AppDatabase(dbAt(359));
    addTearDown(db.close);
    await storedValue(db);
    await expectLater(
      db.customStatement('UPDATE diver_settings SET show_country_flags = 2'),
      throwsA(anything),
    );
  });

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(359, stored: false));
    addTearDown(db.close);
    expect(await storedValue(db), 0);
  });
}
