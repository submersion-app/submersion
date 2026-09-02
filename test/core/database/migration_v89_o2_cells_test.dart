import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// v182/v183 (well past v89 in the same ladder) pack whatever dive_profiles
/// rows this migration produced into dive_profile_series and drop the legacy
/// table, so every assertion below decodes the packed series rather than
/// reading the now-gone legacy table's columns.
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

  test('v89 adds O2 cell columns to dive_profiles, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 88');
        // FK parents the v182/v183 rungs' series tables need to exist at all
        // (_assertProfileSeriesSchema), same as a real database has carried
        // since long before v88.
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute(
          'CREATE TABLE dive_data_sources (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute("INSERT INTO dives (id) VALUES ('dive1')");
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

    // dive_profiles is gone by the time this resolves; the ladder drops it
    // once v183 has packed everything into dive_profile_series.
    final samples = await primarySeriesFor(db, 'dive1');
    expect(samples, [
      const ProfileSample(timestamp: 60, depth: 20.0, setpoint: 0.7),
    ]);
    // Existing rows carry no O2 cell values: only setpoint was seeded.
    expect(samples.single.o2Sensor1, isNull);
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
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute(
            'CREATE TABLE dive_data_sources (id TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute("INSERT INTO dives (id) VALUES ('dive1')");
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

      // Touching the DB runs the ladder; it must not throw on the columns
      // that already exist, and the pre-existing value must survive the
      // pack into dive_profile_series (the newly added cell columns, having
      // never been written, decode as null).
      final samples = await primarySeriesFor(db, 'dive1');
      expect(samples, hasLength(1));
      expect(samples.single.o2Sensor1, 0.95);
      expect(samples.single.o2Sensor3, isNull);
    },
  );
}
