import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v105 adds heading column to dive_profiles, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 104');
        // Minimal pre-v105 dive_profiles shape (no heading column).
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            temperature REAL,
            heart_rate INTEGER
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, heart_rate) "
          "VALUES ('p1', 'dive1', 60, 20.0, 72)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();
    expect(names, contains('heading'));

    final row = await db
        .customSelect(
          "SELECT heart_rate, heading FROM dive_profiles WHERE id = 'p1'",
        )
        .getSingle();
    expect(row.data['heart_rate'], 72);
    // Existing rows read the new column as NULL.
    expect(row.data['heading'], isNull);
  });

  test('v105 migration is idempotent when heading already exists', () async {
    // Exercises the PRAGMA guard branch: no duplicate ALTER.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 104');
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            heading REAL
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, heading) "
          "VALUES ('p1', 'dive1', 60, 20.0, 275.0)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(
      names.where((name) => name == 'heading').length,
      1,
      reason: 'heading should exist exactly once',
    );

    final row = await db
        .customSelect("SELECT heading FROM dive_profiles WHERE id = 'p1'")
        .getSingle();
    expect(row.data['heading'], 275.0);
  });

  test('beforeOpen backstop heals a database already at '
      'currentSchemaVersion that is missing the heading column', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute(
          'PRAGMA user_version = ${AppDatabase.currentSchemaVersion}',
        );
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    expect(cols.map((c) => c.read<String>('name')), contains('heading'));
  });

  test('version ladder includes 105', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(105));
    expect(AppDatabase.migrationVersions, contains(105));
  });
}
