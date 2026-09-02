import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

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

/// FK parents the v182/v183 rungs' series tables need to exist at all
/// (_assertProfileSeriesSchema), same as a real database has carried since
/// long before v150.
void _seedFkParents(dynamic rawDb) {
  rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
  rawDb.execute('CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)');
  rawDb.execute(
    'CREATE TABLE dive_data_sources (id TEXT NOT NULL PRIMARY KEY)',
  );
  rawDb.execute("INSERT INTO dives (id) VALUES ('dive1')");
}

void main() {
  const codec = ProfileSeriesCodec();

  Future<List<ProfileSample>> primarySeriesFor(
    AppDatabase db,
    String diveId,
  ) async {
    final row = await db
        .customSelect(
          'SELECT samples FROM dive_profile_series WHERE dive_id = ?',
          variables: [Variable<String>(diveId)],
        )
        .getSingle();
    return codec.decode(row.read('samples'));
  }

  test('v153 adds O2 cell millivolt columns, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 150');
        _seedFkParents(rawDb);
        rawDb.execute(_preV153DiveProfiles);
        rawDb.execute(
          "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, o2_sensor1) "
          "VALUES ('p1', 'dive1', 60, 20.0, 0.95)",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // dive_profiles is gone by the time this resolves; the ladder drops it
    // once v183 has packed everything into dive_profile_series.
    final samples = await primarySeriesFor(db, 'dive1');
    expect(samples, [
      const ProfileSample(timestamp: 60, depth: 20.0, o2Sensor1: 0.95),
    ]);
    // Existing rows carry no millivolt values: only the bar-based o2Sensor1
    // was seeded.
    expect(samples.single.o2SensorMv1, isNull);
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
          _seedFkParents(rawDb);
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

      // Touching the DB runs the ladder; it must not throw on the columns
      // that already exist, and the pre-existing value must survive the
      // pack into dive_profile_series.
      final samples = await primarySeriesFor(db, 'dive1');
      expect(samples, [
        const ProfileSample(timestamp: 60, depth: 20.0, o2SensorMv1: 58),
      ]);
      expect(samples.single.o2SensorMv3, isNull);
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
