import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v388: the default visibility and the palette colour of the trim
/// line on the dive profile (issue #5098): `default_show_trim` and
/// `profile_color_trim`. Defaulted off or null, no backfill, so the sync
/// floor holds.
void main() {
  NativeDatabase dbAt(int version, {bool withColumns = false}) =>
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = $version');
          final extra = withColumns
              ? ', default_show_trim INTEGER NOT NULL DEFAULT 0, '
                    'profile_color_trim INTEGER'
              : '';
          rawDb.execute(
            'CREATE TABLE diver_settings (id TEXT NOT NULL PRIMARY KEY, '
            'diver_id TEXT NOT NULL$extra)',
          );
          rawDb.execute(
            withColumns
                ? 'INSERT INTO diver_settings (id, diver_id, '
                      'default_show_trim, profile_color_trim) '
                      "VALUES ('s1', 'd1', 1, 4278190080)"
                : "INSERT INTO diver_settings (id, diver_id) "
                      "VALUES ('s1', 'd1')",
          );
        },
      );

  Future<Map<String, Object?>> stored(AppDatabase db) async =>
      (await db
              .customSelect(
                'SELECT default_show_trim, profile_color_trim FROM diver_settings',
              )
              .getSingle())
          .data;

  test('v388 is in the ladder and keeps the floor', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(388));
    expect(AppDatabase.migrationVersions, contains(388));
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(388));
  });

  test('upgrading from v387 adds the columns off and uncoloured', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    expect(await stored(db), {
      'default_show_trim': 0,
      'profile_color_trim': null,
    });
  });

  test('the upgraded visibility column is a boolean', () async {
    final db = AppDatabase(dbAt(387));
    addTearDown(db.close);
    await stored(db);
    await expectLater(
      db.customStatement('UPDATE diver_settings SET default_show_trim = 2'),
      throwsA(anything),
    );
  });

  test('a database already carrying the columns keeps its values', () async {
    final db = AppDatabase(dbAt(387, withColumns: true));
    addTearDown(db.close);
    expect(await stored(db), {
      'default_show_trim': 1,
      'profile_color_trim': 4278190080,
    });
  });
}
