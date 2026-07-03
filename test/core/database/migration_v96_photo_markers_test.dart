import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v96 adds default_show_photo_markers to diver_settings, default 1',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 95');
          // Minimal pre-v96 diver_settings shape: just enough columns to
          // insert a row. The v96 migration adds default_show_photo_markers.
          rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute(
            "INSERT INTO diver_settings (id, diver_id, created_at, updated_at) "
            "VALUES ('s1', 'd1', 1, 1)",
          );
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('default_show_photo_markers'));

      // Existing rows read the new column as the SQL default (1 / true).
      final row = await db
          .customSelect(
            "SELECT default_show_photo_markers FROM diver_settings "
            "WHERE id = 's1'",
          )
          .getSingle();
      expect(row.data['default_show_photo_markers'], 1);
    },
  );

  test('v96 is in the migration ladder', () {
    // v96 is a past migration; the latest-version tripwire lives in the newest
    // version's test (issue #164's checklist migration is v98). It must remain
    // in the ladder so upgrade step counts stay correct.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(96));
    expect(AppDatabase.migrationVersions, contains(96));
  });

  test('v96 migration is idempotent when the column already exists', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 95');
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            default_show_photo_markers INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO diver_settings "
          "(id, diver_id, default_show_photo_markers, created_at, updated_at) "
          "VALUES ('s1', 'd1', 0, 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('diver_settings')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();

    // Column present exactly once (no duplicate ALTER).
    expect(names.where((n) => n == 'default_show_photo_markers').length, 1);

    // The pre-existing value is preserved, not reset to the new default.
    final row = await db
        .customSelect(
          "SELECT default_show_photo_markers FROM diver_settings "
          "WHERE id = 's1'",
        )
        .getSingle();
    expect(row.data['default_show_photo_markers'], 0);
  });
}
