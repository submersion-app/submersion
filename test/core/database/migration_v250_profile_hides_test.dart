import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// Schema v250: trip_hides and site_hides, a profile's hidden shared trips
/// and sites (issue #2594).
void main() {
  /// A v249 database with only the parents the hides point at.
  NativeDatabase setupDb({bool withParents = true}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 249');
      rawDb.execute('CREATE TABLE divers (id TEXT NOT NULL PRIMARY KEY)');
      if (withParents) {
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test('v250 is at or below the current schema version and in the ladder', () {
    // Relaxed once v251 (dive_tanks.source_id, #2716) landed on top; the
    // newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(250));
    expect(AppDatabase.migrationVersions, contains(250));
    expect(AppDatabase.migrationStepCount(249), greaterThanOrEqualTo(1));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v249 creates both tables', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_hides'), {
      'id',
      'trip_id',
      'diver_id',
      'created_at',
      'hlc',
    });
    expect(await columnsOf(db, 'site_hides'), {
      'id',
      'site_id',
      'diver_id',
      'created_at',
      'hlc',
    });
  });

  test('a profile hides a trip or a site once', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement("INSERT INTO divers (id) VALUES ('d1')");
    await db.customStatement("INSERT INTO trips (id) VALUES ('t1')");
    await db.customStatement("INSERT INTO dive_sites (id) VALUES ('s1')");
    await db.customStatement(
      "INSERT INTO trip_hides (id, trip_id, diver_id, created_at) "
      "VALUES ('a', 't1', 'd1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO trip_hides (id, trip_id, diver_id, created_at) "
        "VALUES ('b', 't1', 'd1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
    await db.customStatement(
      "INSERT INTO site_hides (id, site_id, diver_id, created_at) "
      "VALUES ('c', 's1', 'd1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO site_hides (id, site_id, diver_id, created_at) "
        "VALUES ('d', 's1', 'd1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('a fixture without the parents gains no hides tables', () async {
    final db = AppDatabase(setupDb(withParents: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_hides'), isEmpty);
    expect(await columnsOf(db, 'site_hides'), isEmpty);
  });

  test('a fresh database has both tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'trip_hides'), contains('trip_id'));
    expect(await columnsOf(db, 'site_hides'), contains('site_id'));
  });
}
