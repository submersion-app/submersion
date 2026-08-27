import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v94 adds ascent_gas_set to diver_settings, default 0', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 93');
        // Minimal pre-v94 diver_settings shape: just enough columns to insert
        // a row. The v94 migration adds ascent_gas_set.
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
    expect(names, contains('ascent_gas_set'));

    // Existing rows read the new column as the SQL default (0 = allCarried).
    final row = await db
        .customSelect(
          "SELECT ascent_gas_set FROM diver_settings WHERE id = 's1'",
        )
        .getSingle();
    expect(row.data['ascent_gas_set'], 0);
  });

  test('v94 is in the migration ladder', () {
    // v94 is now a past migration (the latest-version tripwire lives in the
    // newest version's test). It must remain in the ladder.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(94));
    expect(AppDatabase.migrationVersions, contains(94));
  });

  test('v94 migration is guarded when diver_settings is absent', () async {
    // Minimal-schema migration test: no diver_settings table. The v94
    // migration block must not throw when the table is missing.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 93');
        // Only a dummy table — no diver_settings.
        rawDb.execute('''
          CREATE TABLE dummy (id TEXT NOT NULL PRIMARY KEY)
        ''');
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Should complete without throwing.
    await expectLater(db.customSelect('SELECT 1').get(), completes);
  });
}
