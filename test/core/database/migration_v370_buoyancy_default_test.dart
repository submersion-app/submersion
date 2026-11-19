import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v370: diver_settings.default_show_buoyancy, the default
/// visibility of the net buoyancy line on the dive profile
/// (issue #4593). Defaulted off, no backfill, so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool? stored}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${stored != null ? ', default_show_buoyancy INTEGER NOT NULL DEFAULT 0' : ''})",
      );
      rawDb.execute(
        stored != null
            ? 'INSERT INTO diver_settings '
                  '(id, diver_id, default_show_buoyancy) '
                  "VALUES ('s1', 'd1', ${stored ? 1 : 0})"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  Future<int> storedValue(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT default_show_buoyancy AS v '
                'FROM diver_settings',
              )
              .getSingle())
          .read<int>('v');

  test('v370 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(370));
    expect(AppDatabase.migrationVersions, contains(370));
  });

  test('the new column is defaulted and kept the floor', () {
    // A later rung (v378, the marks on app-applied species tags) raised the
    // floor; v370 itself did not set it.
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(370));
  });

  test('upgrading from v369 adds the column switched off', () async {
    final db = AppDatabase(dbAt(369));
    addTearDown(db.close);
    expect(await storedValue(db), 0);
  });

  test('the upgraded column is a boolean, as on a fresh install', () async {
    final db = AppDatabase(dbAt(369));
    addTearDown(db.close);
    await storedValue(db);
    await expectLater(
      db.customStatement('UPDATE diver_settings SET default_show_buoyancy = 2'),
      throwsA(anything),
    );
  });

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(369, stored: true));
    addTearDown(db.close);
    expect(await storedValue(db), 1);
  });
}
