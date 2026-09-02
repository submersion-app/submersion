import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// v182/v183 (well past v105 in the same ladder) pack whatever dive_profiles
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

  test('v105 adds heading column to dive_profiles, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 104');
        // FK parents the v182/v183 rungs' series tables need to exist at all
        // (_assertProfileSeriesSchema), same as a real database has carried
        // since long before v104.
        rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute(
          'CREATE TABLE dive_data_sources (id TEXT NOT NULL PRIMARY KEY)',
        );
        rawDb.execute("INSERT INTO dives (id) VALUES ('dive1')");
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

    // dive_profiles is gone by the time this resolves; the ladder drops it
    // once v183 has packed everything into dive_profile_series.
    final samples = await primarySeriesFor(db, 'dive1');
    expect(samples, [
      const ProfileSample(timestamp: 60, depth: 20.0, heartRate: 72),
    ]);
    // Existing rows carry no heading value: only heart_rate was seeded.
    expect(samples.single.heading, isNull);
  });

  test('v105 migration is idempotent when heading already exists', () async {
    // Exercises the PRAGMA guard branch: no duplicate ALTER.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 104');
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

    // Touching the DB runs the ladder; it must not throw on the column that
    // already exists, and the pre-existing value must survive the pack into
    // dive_profile_series.
    final samples = await primarySeriesFor(db, 'dive1');
    expect(samples, [
      const ProfileSample(timestamp: 60, depth: 20.0, heading: 275.0),
    ]);
  });

  // "beforeOpen backstop heals a database already at currentSchemaVersion
  // that is missing the heading column" is deleted: at v183+ a real database
  // never has a dive_profiles table at all, and the earlier, unconditional
  // beforeOpen backstop (pack-then-drop once _storedSchemaVersion >= 183)
  // runs before the heading-specific backstop ever sees the table, so it
  // drops a hand-built dive_profiles out from under this scenario before the
  // heading heal can fire. The self-heal this test pinned no longer has a
  // reachable case.

  test('version ladder includes 105', () {
    // Exact-latest tripwire handed off to the newest migration's test
    // (v106, Lightroom connector suggestions).
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(105));
    expect(AppDatabase.migrationVersions, contains(105));
  });
}
