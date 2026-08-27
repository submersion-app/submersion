import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('v89 adds O2 cell columns to dive_profiles, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 88');
        // Minimal pre-v89 dive_profiles shape (no O2 cell columns).
        rawDb.execute('''
          CREATE TABLE dive_profiles (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            is_primary INTEGER NOT NULL DEFAULT 1,
            timestamp INTEGER NOT NULL,
            depth REAL NOT NULL,
            pp_o2 REAL,
            setpoint REAL
          )
        ''');
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, setpoint) "
          "VALUES ('p1', 'dive1', 60, 20.0, 0.7)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Touch the DB so the migration runs.
    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();

    expect(
      names,
      containsAll(<String>{
        'o2_sensor1',
        'o2_sensor2',
        'o2_sensor3',
        'o2_sensor4',
        'o2_sensor5',
        'o2_sensor6',
      }),
    );

    final row = await db
        .customSelect(
          "SELECT setpoint, o2_sensor1 FROM dive_profiles WHERE id = 'p1'",
        )
        .getSingle();
    expect(row.data['setpoint'], 0.7);
    // Existing rows read the new cell columns as NULL.
    expect(row.data['o2_sensor1'], isNull);
  });

  test('migration list includes v89 and schema is at least 89', () {
    // Guards that the v89 onUpgrade step stays registered. The exact-latest
    // tripwire lives in the newest version's migration test.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(89));
    expect(AppDatabase.migrationVersions, contains(89));
  });

  test(
    'v89 migration is idempotent when some O2 cell columns already exist',
    () async {
      // Exercises the PRAGMA guard branch: a database where part of the v89
      // change is already present (e.g. an interrupted upgrade) must add only
      // the missing columns rather than failing on a duplicate ALTER.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 88');
          rawDb.execute('''
            CREATE TABLE dive_profiles (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL,
              is_primary INTEGER NOT NULL DEFAULT 1,
              timestamp INTEGER NOT NULL,
              depth REAL NOT NULL,
              pp_o2 REAL,
              setpoint REAL,
              o2_sensor1 REAL,
              o2_sensor2 REAL
            )
          ''');
          rawDb.execute(
            "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, o2_sensor1) "
            "VALUES ('p1', 'dive1', 60, 20.0, 0.95)",
          );
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      // Touching the DB runs the migration; it must not throw on the columns
      // that already exist.
      final cols = await db
          .customSelect("PRAGMA table_info('dive_profiles')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toList();

      // All six cell columns present, each exactly once (no duplicate ALTER).
      for (var n = 1; n <= 6; n++) {
        expect(
          names.where((name) => name == 'o2_sensor$n').length,
          1,
          reason: 'o2_sensor$n should exist exactly once',
        );
      }

      // The pre-existing column keeps its data; the newly added ones read NULL.
      final row = await db
          .customSelect(
            "SELECT o2_sensor1, o2_sensor3 FROM dive_profiles WHERE id = 'p1'",
          )
          .getSingle();
      expect(row.data['o2_sensor1'], 0.95);
      expect(row.data['o2_sensor3'], isNull);
    },
  );
}
