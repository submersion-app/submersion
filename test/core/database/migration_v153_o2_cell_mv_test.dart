import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Pre-v153 dive_profiles shape: the ppO2-in-bar cells exist, the millivolt
/// columns do not.
const _preV153DiveProfiles = '''
  CREATE TABLE dive_profiles (
    id TEXT NOT NULL PRIMARY KEY,
    dive_id TEXT NOT NULL,
    is_primary INTEGER NOT NULL DEFAULT 1,
    timestamp INTEGER NOT NULL,
    depth REAL NOT NULL,
    pp_o2 REAL,
    setpoint REAL,
    o2_sensor1 REAL,
    o2_sensor2 REAL,
    o2_sensor3 REAL,
    o2_sensor4 REAL,
    o2_sensor5 REAL,
    o2_sensor6 REAL
  )
''';

void main() {
  test('v153 adds O2 cell millivolt columns, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 150');
        rawDb.execute(_preV153DiveProfiles);
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, o2_sensor1) "
          "VALUES ('p1', 'dive1', 60, 20.0, 0.95)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db
        .customSelect("PRAGMA table_info('dive_profiles')")
        .get();
    final names = cols.map((c) => c.read<String>('name')).toSet();

    expect(
      names,
      containsAll(<String>{
        'o2_sensor_mv1',
        'o2_sensor_mv2',
        'o2_sensor_mv3',
        'o2_sensor_mv4',
        'o2_sensor_mv5',
        'o2_sensor_mv6',
      }),
    );

    // Millivolts are whole numbers, not partial pressures: a REAL column here
    // would silently round-trip through a double.
    for (final col in cols) {
      if (col.read<String>('name').startsWith('o2_sensor_mv')) {
        expect(col.read<String>('type').toUpperCase(), 'INTEGER');
      }
    }

    final row = await db
        .customSelect(
          "SELECT o2_sensor1, o2_sensor_mv1 FROM dive_profiles WHERE id = 'p1'",
        )
        .getSingle();
    expect(row.data['o2_sensor1'], 0.95);
    // Existing rows read the new columns as NULL.
    expect(row.data['o2_sensor_mv1'], isNull);
  });

  test('migration list includes v153 and schema is at least 153', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(153));
    expect(AppDatabase.migrationVersions, contains(153));
  });

  test(
    'v153 migration is idempotent when some millivolt columns already exist',
    () async {
      // An interrupted upgrade leaves part of the change applied. The PRAGMA
      // guard must add only what is missing rather than failing on a duplicate
      // ALTER.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 150');
          rawDb.execute(_preV153DiveProfiles);
          rawDb.execute(
            'ALTER TABLE dive_profiles ADD COLUMN o2_sensor_mv1 INTEGER',
          );
          rawDb.execute(
            'ALTER TABLE dive_profiles ADD COLUMN o2_sensor_mv2 INTEGER',
          );
          rawDb.execute(
            "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, o2_sensor_mv1) "
            "VALUES ('p1', 'dive1', 60, 20.0, 58)",
          );
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final cols = await db
          .customSelect("PRAGMA table_info('dive_profiles')")
          .get();
      final names = cols.map((c) => c.read<String>('name')).toList();

      for (var n = 1; n <= 6; n++) {
        expect(
          names.where((name) => name == 'o2_sensor_mv$n').length,
          1,
          reason: 'o2_sensor_mv$n should exist exactly once',
        );
      }

      final row = await db
          .customSelect(
            "SELECT o2_sensor_mv1, o2_sensor_mv3 FROM dive_profiles "
            "WHERE id = 'p1'",
          )
          .getSingle();
      expect(row.data['o2_sensor_mv1'], 58);
      expect(row.data['o2_sensor_mv3'], isNull);
    },
  );

  test('the helper no-ops when dive_profiles is absent', () async {
    // Partial-schema case: migration tests instantiate databases without
    // unrelated tables, and unguarded DDL would fail with "no such table".
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 150');
        // Deliberately no dive_profiles table at all.
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Touching the DB runs the migration; it must not throw.
    final result = await db.customSelect('SELECT 1 AS ok').getSingle();
    expect(result.data['ok'], 1);
  });
}
