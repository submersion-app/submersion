import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v248: trip_equipment, gear packed for a trip (issue #2338).
void main() {
  /// A v247 database with only the parents trip_equipment points at.
  NativeDatabase setupDb({bool withTrips = true}) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 247');
      rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
      rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
      if (withTrips) {
        rawDb.execute('CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY)');
      }
    },
  );

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<bool> hasIndex(AppDatabase db, String name) async =>
      (await db
              .customSelect(
                "SELECT name FROM sqlite_master WHERE type = 'index' AND name = ?",
                variables: [Variable(name)],
              )
              .get())
          .isNotEmpty;

  test('v248 is at or below the current schema version and in the '
      'ladder', () {
    // Relaxed once v249 (the trip fill forecast) landed on top; the newest
    // rung owns the exact assertion.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(248));
    expect(AppDatabase.migrationVersions, contains(248));
  });

  test('upgrading from v247 creates trip_equipment and its index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_equipment'), {
      'id',
      'trip_id',
      'equipment_id',
      'created_at',
      'hlc',
    });
    expect(await hasIndex(db, 'idx_trip_equipment_equipment'), isTrue);
  });

  test('the (trip, item) pair is unique', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customStatement("INSERT INTO trips (id) VALUES ('t1')");
    await db.customStatement("INSERT INTO equipment (id) VALUES ('e1')");
    await db.customStatement(
      "INSERT INTO trip_equipment (id, trip_id, equipment_id, created_at) "
      "VALUES ('a', 't1', 'e1', 0)",
    );
    await expectLater(
      db.customStatement(
        "INSERT INTO trip_equipment (id, trip_id, equipment_id, created_at) "
        "VALUES ('b', 't1', 'e1', 0)",
      ),
      throwsA(isA<SqliteException>()),
    );
  });

  test('a fixture without trips gains no trip_equipment', () async {
    final db = AppDatabase(setupDb(withTrips: false));
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(await columnsOf(db, 'trip_equipment'), isEmpty);
  });
}
