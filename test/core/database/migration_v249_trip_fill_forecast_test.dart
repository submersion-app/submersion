import 'package:drift/drift.dart' show QueryRow;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v249: the trip fill forecast's inputs (issue #2325, PR 4). Columns only,
/// no backfill: trips.divers_sharing_cylinders (not null, default 1),
/// trips.dives_per_day_target, trip_itinerary_days.planned_dives, and the
/// dive center fill hours in minutes after local midnight. 248 is held by
/// #2585. The sync floor does not move: an older peer ignores the columns,
/// and the serializer fills the not-null default for a payload without it.
void main() {
  const expected = {
    'trips': {'divers_sharing_cylinders', 'dives_per_day_target'},
    'trip_itinerary_days': {'planned_dives'},
    'dive_centers': {'fill_opens_at', 'fill_closes_at'},
  };

  Future<Map<String, QueryRow>> columns(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA table_info('$table')").get();
    return {for (final r in rows) r.read<String>('name'): r};
  }

  NativeDatabase strandedAt(int userVersion) => NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = $userVersion');
      rawDb.execute(
        'CREATE TABLE trips (id TEXT NOT NULL PRIMARY KEY, name TEXT)',
      );
      rawDb.execute(
        'CREATE TABLE trip_itinerary_days (id TEXT NOT NULL PRIMARY KEY)',
      );
      rawDb.execute('CREATE TABLE dive_centers (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute("INSERT INTO trips (id, name) VALUES ('t1', 'Bonaire')");
    },
  );

  test('v249 is at or below the current schema version and in the ladder', () {
    // Relaxed once v250 (profile hides, #2594) and v251
    // (dive_tanks.source_id, #2716) landed on top; the newest rung owns
    // the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(249));
    expect(AppDatabase.migrationVersions, contains(249));
    // 248 (trip_equipment, #2338) sits below this rung.
    expect(AppDatabase.migrationVersions, contains(248));
    expect(AppDatabase.migrationStepCount(248), greaterThanOrEqualTo(1));
    expect(AppDatabase.migrationStepCount(247), greaterThanOrEqualTo(2));
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('a fresh database has every column; sharing is not null, 1', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    for (final MapEntry(key: table, value: names) in expected.entries) {
      final cols = await columns(db, table);
      for (final name in names) {
        expect(cols.keys, contains(name), reason: '$table.$name');
      }
    }
    final sharing = (await columns(db, 'trips'))['divers_sharing_cylinders']!;
    expect(sharing.read<int>('notnull'), 1);
    expect(sharing.read<String?>('dflt_value'), contains('1'));
    final target = (await columns(db, 'trips'))['dives_per_day_target']!;
    expect(target.read<int>('notnull'), 0);
  });

  test('a database at v247 gains the columns; its trip shares one', () async {
    final db = AppDatabase(strandedAt(247));
    addTearDown(db.close);
    for (final MapEntry(key: table, value: names) in expected.entries) {
      expect((await columns(db, table)).keys, containsAll(names));
    }
    final row = await db
        .customSelect(
          "SELECT divers_sharing_cylinders AS n FROM trips WHERE id = 't1'",
        )
        .getSingle();
    expect(row.read<int>('n'), 1);
  });

  test('a database already at v249 without them regains them', () async {
    final db = AppDatabase(strandedAt(AppDatabase.currentSchemaVersion));
    addTearDown(db.close);
    for (final MapEntry(key: table, value: names) in expected.entries) {
      expect((await columns(db, table)).keys, containsAll(names));
    }
  });
}
