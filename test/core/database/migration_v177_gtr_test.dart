import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_sample.dart';
import 'package:submersion/features/dive_log/domain/codecs/profile_series_codec.dart';

/// v177: the three GTR settings on diver_settings, plus a repair of
/// dive_profiles.rbt. libdivecomputer reports RBT/GTR in minutes but every
/// app path stored the raw value in a column documented as seconds, so rows
/// that came through libdc (the only ones with raw bytes on their data source)
/// are scaled by 60; file imports (Subsurface, UDDF) already wrote seconds and
/// are left alone.
///
/// dive_profiles carries timestamp/depth (unused by the v177 rung itself)
/// and dives/dive_computers exist purely so v182/v183, later in the same
/// ladder, can pack the rows into dive_profile_series: every real
/// dive_profiles row has always had them, and without a valid sample shape
/// there would be nowhere for the rbt value this migration writes to survive
/// the v183 drop.
NativeDatabase _dbAt176({void Function(dynamic rawDb)? seed}) {
  return NativeDatabase.memory(
    setup: (rawDb) {
      rawDb.execute('PRAGMA user_version = 176');
      rawDb.execute('''
        CREATE TABLE diver_settings (
          id TEXT NOT NULL PRIMARY KEY
        )
      ''');
      rawDb.execute("INSERT INTO diver_settings (id) VALUES ('settings')");
      rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
      rawDb.execute(
        'CREATE TABLE dive_computers (id TEXT NOT NULL PRIMARY KEY)',
      );
      rawDb.execute('''
        CREATE TABLE dive_data_sources (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          raw_data BLOB
        )
      ''');
      rawDb.execute('''
        CREATE TABLE dive_profiles (
          id TEXT NOT NULL PRIMARY KEY,
          dive_id TEXT NOT NULL,
          timestamp INTEGER NOT NULL,
          depth REAL NOT NULL,
          rbt INTEGER
        )
      ''');
      seed?.call(rawDb);
    },
  );
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final cols = await db.customSelect("PRAGMA table_info('$table')").get();
  return cols.map((c) => c.read<String>('name')).toSet();
}

void main() {
  test('v177 adds the GTR settings columns with their defaults', () async {
    final db = AppDatabase(_dbAt176());
    addTearDown(db.close);

    final names = await _columns(db, 'diver_settings');
    expect(names, contains('default_show_gtr'));
    expect(names, contains('default_gtr_source'));
    expect(names, contains('gtr_reserve_pressure'));

    final row = await db
        .customSelect(
          'SELECT default_show_gtr, default_gtr_source, gtr_reserve_pressure '
          'FROM diver_settings',
        )
        .getSingle();
    expect(row.read<int>('default_show_gtr'), 0);
    expect(row.read<int>('default_gtr_source'), 1);
    expect(row.read<double>('gtr_reserve_pressure'), 50.0);
  });

  test('v177 scales libdc-sourced rbt from minutes to seconds', () async {
    final db = AppDatabase(
      _dbAt176(
        seed: (rawDb) {
          rawDb.execute(
            "INSERT INTO dives (id) VALUES ('downloaded'), ('imported'), "
            "('orphan')",
          );
          rawDb.execute(
            "INSERT INTO dive_data_sources VALUES ('s1', 'downloaded', ?)",
            [
              Uint8List.fromList([1, 2, 3]),
            ],
          );
          rawDb.execute(
            "INSERT INTO dive_data_sources VALUES ('s2', 'imported', NULL)",
          );
          // p1 and p2 share a dive and neither carries computer_id/source_id
          // (absent from this fixture's dive_profiles), so distinct
          // timestamps are what keeps them from merging into one packed
          // sample when v182/v183 later dedupe exact duplicates.
          rawDb.execute(
            "INSERT INTO dive_profiles (id, dive_id, timestamp, depth, rbt) "
            "VALUES "
            "('p1', 'downloaded', 0, 10.0, 25), "
            "('p2', 'downloaded', 60, 10.0, NULL), "
            "('p3', 'imported', 0, 10.0, 1500), "
            "('p4', 'orphan', 0, 10.0, 30)",
          );
        },
      ),
    );
    addTearDown(db.close);

    // dive_profiles is gone by the time this resolves; the ladder drops it
    // once v183 has packed everything into dive_profile_series.
    const codec = ProfileSeriesCodec();
    Future<List<ProfileSample>> rbtSamplesFor(String diveId) async {
      final row = await db
          .customSelect(
            'SELECT samples FROM dive_profile_series WHERE dive_id = ?',
            variables: [Variable<String>(diveId)],
          )
          .getSingle();
      return codec.decode(row.read('samples'));
    }

    final downloaded = await rbtSamplesFor('downloaded');
    final byTimestamp = {for (final s in downloaded) s.timestamp: s.rbt};
    // Downloaded through libdc: 25 min becomes 1500 s.
    expect(byTimestamp[0], 1500);
    expect(byTimestamp[60], isNull);

    // Subsurface/UDDF import already wrote seconds.
    expect((await rbtSamplesFor('imported')).single.rbt, 1500);

    // No data source at all: nothing known about its origin, leave it.
    expect((await rbtSamplesFor('orphan')).single.rbt, 30);
  });

  test('fresh databases get the GTR settings columns', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    final names = await _columns(db, 'diver_settings');
    expect(names, contains('default_show_gtr'));
    expect(names, contains('default_gtr_source'));
    expect(names, contains('gtr_reserve_pressure'));
  });

  test('v177 is present in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(177));
    expect(AppDatabase.migrationVersions, contains(177));
  });
}
