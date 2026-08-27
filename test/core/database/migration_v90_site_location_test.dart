import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test(
    'v90 adds city and island columns to dive_sites, preserving rows',
    () async {
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 89');
          // Minimal pre-v90 dive_sites shape (body_of_water already exists from
          // an earlier migration; city and island do not).
          rawDb.execute('''
          CREATE TABLE dive_sites (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            body_of_water TEXT,
            country TEXT,
            region TEXT,
            is_shared INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
          rawDb.execute(
            "INSERT INTO dive_sites (id, name, country, created_at, updated_at) "
            "VALUES ('s1', 'Old Site', 'Philippines', 1, 1)",
          );
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      // Touch the DB so the migration runs.
      final cols = await db
          .customSelect("PRAGMA table_info('dive_sites')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toSet();

      expect(names, containsAll(<String>{'city', 'island'}));

      final row = await db
          .customSelect(
            "SELECT country, city, island FROM dive_sites WHERE id = 's1'",
          )
          .getSingle();
      expect(row.data['country'], 'Philippines');
      // Existing rows read the new locality columns as NULL.
      expect(row.data['city'], isNull);
      expect(row.data['island'], isNull);
    },
  );

  test('schema version is at least 90 and the migration list includes it', () {
    // Bumping the schema must come with a matching migration block. Uses
    // greaterThanOrEqualTo so a later bump does not break this version's test;
    // the exact-latest tripwire lives in the newest migration test.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(90));
    expect(AppDatabase.migrationVersions, contains(90));
  });

  test('v90 migration is idempotent when city already exists', () async {
    // Exercises the PRAGMA guard branch: a database where part of the v90
    // change is already present (e.g. an interrupted upgrade) must add only
    // the missing column rather than failing on a duplicate ALTER.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 89');
        rawDb.execute('''
          CREATE TABLE dive_sites (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            description TEXT NOT NULL DEFAULT '',
            body_of_water TEXT,
            country TEXT,
            region TEXT,
            city TEXT,
            is_shared INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_sites (id, name, city, created_at, updated_at) "
          "VALUES ('s1', 'Old Site', 'Cebu City', 1, 1)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('dive_sites')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();

    // Both columns present, each exactly once (no duplicate ALTER).
    expect(names.where((n) => n == 'city').length, 1);
    expect(names.where((n) => n == 'island').length, 1);

    // The pre-existing column keeps its data; the newly added one reads NULL.
    final row = await db
        .customSelect("SELECT city, island FROM dive_sites WHERE id = 's1'")
        .getSingle();
    expect(row.data['city'], 'Cebu City');
    expect(row.data['island'], isNull);
  });
}
