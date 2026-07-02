import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v95 adds name column to dives, null for existing rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 94');
        // Minimal pre-v95 dives shape: just enough columns to insert a row.
        // The v95 migration adds the name column.
        rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_date_time INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL
        )
      ''');
        rawDb.execute(
          "INSERT INTO dives (id, dive_date_time, created_at, updated_at) "
          "VALUES ('d1', 1, 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Touch the DB so the migration runs.
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('name'));

    // Existing rows read the new column as NULL.
    final row = await db
        .customSelect("SELECT name FROM dives WHERE id = 'd1'")
        .getSingle();
    expect(row.data['name'], isNull);
  });

  test('v95 is the current version and in the migration ladder', () {
    // Latest-version tripwire: bumping the schema must come with a matching
    // migration block and an update here.
    expect(AppDatabase.currentSchemaVersion, 95);
    expect(AppDatabase.migrationVersions, contains(95));
    expect(AppDatabase.migrationVersions.last, 95);
  });

  test('v95 migration is idempotent when the column already exists', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 94');
        rawDb.execute('''
        CREATE TABLE dives (
          id TEXT NOT NULL PRIMARY KEY,
          dive_date_time INTEGER NOT NULL,
          created_at INTEGER NOT NULL,
          updated_at INTEGER NOT NULL,
          name TEXT
        )
      ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Must not fail on a duplicate ALTER.
    final cols = await db.customSelect("PRAGMA table_info('dives')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'name').length, 1);
  });
}
