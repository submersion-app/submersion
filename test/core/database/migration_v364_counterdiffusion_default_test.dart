import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v364: diver_settings.default_show_counterdiffusion, the default
/// visibility of the isobaric counterdiffusion overlay on the dive profile
/// (issue #4530). Defaulted off, no backfill, so the sync floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool? stored}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $version');
      rawDb.execute(
        'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
        'diver_id TEXT NOT NULL'
        "${stored != null ? ', default_show_counterdiffusion INTEGER NOT NULL DEFAULT 0' : ''})",
      );
      rawDb.execute(
        stored != null
            ? 'INSERT INTO diver_settings '
                  '(id, diver_id, default_show_counterdiffusion) '
                  "VALUES ('s1', 'd1', ${stored ? 1 : 0})"
            : "INSERT INTO diver_settings (id, diver_id) VALUES ('s1', 'd1')",
      );
    },
  );

  Future<int> storedValue(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT default_show_counterdiffusion AS v '
                'FROM diver_settings',
              )
              .getSingle())
          .read<int>('v');

  test('v364 is in the ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(364));
    expect(AppDatabase.migrationVersions, contains(364));
  });

  test('the new column is defaulted and kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(364));
  });

  test('upgrading from v363 adds the column switched off', () async {
    final db = AppDatabase(dbAt(363));
    addTearDown(db.close);
    expect(await storedValue(db), 0);
  });

  test('the upgraded column is a boolean, as on a fresh install', () async {
    final db = AppDatabase(dbAt(363));
    addTearDown(db.close);
    await storedValue(db);
    await expectLater(
      db.customStatement(
        'UPDATE diver_settings SET default_show_counterdiffusion = 2',
      ),
      throwsA(anything),
    );
  });

  test('a database already carrying the column keeps its value', () async {
    final db = AppDatabase(dbAt(363, stored: true));
    addTearDown(db.close);
    expect(await storedValue(db), 1);
  });
}
