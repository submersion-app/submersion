import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v91 adds default_show_ascent_rate_line to diver_settings, default 0',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 90');
          // Minimal pre-v91 diver_settings shape: just enough columns to insert
          // a row. The v91 migration adds default_show_ascent_rate_line.
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

      // Touch the DB so the migration runs.
      final cols = await db
          .customSelect("PRAGMA table_info('diver_settings')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();
      expect(names, contains('default_show_ascent_rate_line'));

      // Existing rows read the new column as the SQL default (0 / false).
      final row = await db
          .customSelect(
            "SELECT default_show_ascent_rate_line FROM diver_settings "
            "WHERE id = 's1'",
          )
          .getSingle();
      expect(row.data['default_show_ascent_rate_line'], 0);
    },
  );

  test('schema version is 91 and the migration list includes it', () {
    // Latest-version tripwire: bumping the schema must come with a matching
    // migration block and an update here.
    expect(AppDatabase.currentSchemaVersion, 91);
    expect(AppDatabase.migrationVersions, contains(91));
  });

  test('v91 migration is idempotent when the column already exists', () async {
    // Exercises the PRAGMA guard branch: a database where the v91 column is
    // already present (e.g. an interrupted upgrade) must not fail on a
    // duplicate ALTER.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 90');
        rawDb.execute('''
          CREATE TABLE diver_settings (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT NOT NULL,
            default_show_ascent_rate_line INTEGER NOT NULL DEFAULT 1,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO diver_settings "
          "(id, diver_id, default_show_ascent_rate_line, created_at, updated_at) "
          "VALUES ('s1', 'd1', 1, 1, 1)",
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
    expect(names.where((n) => n == 'default_show_ascent_rate_line').length, 1);

    // The pre-existing value is preserved, not reset to the new default.
    final row = await db
        .customSelect(
          "SELECT default_show_ascent_rate_line FROM diver_settings "
          "WHERE id = 's1'",
        )
        .getSingle();
    expect(row.data['default_show_ascent_rate_line'], 1);
  });
}
