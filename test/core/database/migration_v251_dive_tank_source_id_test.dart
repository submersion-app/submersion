import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v251: dive_tanks.source_id (issue #2716). Two consolidated sources
/// that name no computer both leave their tank rows with a null computer, so
/// two copies of one cylinder could not be told apart.
void main() {
  /// A v249 database with the tables the rung touches, and tanks on four
  /// dives:
  ///
  /// * d1 has one source: its tanks take it.
  /// * d2 has two sources on different computers: each tank takes the
  ///   source of its computer.
  /// * d3 has two computer-less sources: each tank takes the source of its
  ///   own pressure series; a tank with no series, or with series from both
  ///   sources (a merged cylinder), stays null.
  /// * d4 has no source at all (a manual dive): its tank stays null.
  NativeDatabase setupDb({int userVersion = 249}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        for (final table in const [
          'divers',
          'dive_sites',
          'dives',
          'dive_centers',
          'dive_computers',
          'equipment',
        ]) {
          rawDb.execute('CREATE TABLE $table (id TEXT PRIMARY KEY)');
        }
        rawDb.execute('CREATE TABLE media (id TEXT PRIMARY KEY, hlc TEXT)');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE dive_tanks (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            computer_id TEXT
          )
        ''');
        rawDb.execute('''
          CREATE TABLE tank_pressure_series (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            tank_id TEXT NOT NULL,
            computer_id TEXT,
            source_id TEXT
          )
        ''');
        rawDb.execute('''
          INSERT INTO dive_data_sources (id, dive_id, computer_id) VALUES
            ('src1', 'd1', NULL),
            ('src2a', 'd2', 'c1'),
            ('src2b', 'd2', 'c2'),
            ('src3a', 'd3', NULL),
            ('src3b', 'd3', NULL)
        ''');
        rawDb.execute('''
          INSERT INTO dive_tanks (id, dive_id, computer_id) VALUES
            ('t1', 'd1', NULL),
            ('t1x', 'd1', 'c9'),
            ('t2a', 'd2', 'c1'),
            ('t2b', 'd2', 'c2'),
            ('t3a', 'd3', NULL),
            ('t3b', 'd3', NULL),
            ('t3c', 'd3', NULL),
            ('t3d', 'd3', NULL),
            ('t4', 'd4', NULL)
        ''');
        rawDb.execute('''
          INSERT INTO tank_pressure_series
            (id, dive_id, tank_id, computer_id, source_id)
          VALUES
            ('s3a', 'd3', 't3a', NULL, 'src3a'),
            ('s3b', 'd3', 't3b', NULL, 'src3b'),
            ('s3d1', 'd3', 't3d', NULL, 'src3a'),
            ('s3d2', 'd3', 't3d', NULL, 'src3b')
        ''');
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Map<String, String?>> sourceIds(AppDatabase db) async {
    final rows = await db
        .customSelect('SELECT id, source_id FROM dive_tanks')
        .get();
    return {
      for (final r in rows) r.read<String>('id'): r.read<String?>('source_id'),
    };
  }

  test('v251 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 251);
    expect(AppDatabase.migrationVersions, contains(251));
    // 250 is claimed by open PRs (#2675, #2562), so this rung sits right
    // above 249 for now.
    expect(AppDatabase.migrationStepCount(249), 1);
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 240);
  });

  test('upgrading from v249 attributes the unambiguous tanks', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_tanks'), contains('source_id'));
    expect(await sourceIds(db), {
      't1': 'src1',
      // Names a computer the only source is not: not that source's.
      't1x': null,
      't2a': 'src2a',
      't2b': 'src2b',
      't3a': 'src3a',
      't3b': 'src3b',
      't3c': null,
      't3d': null,
      't4': null,
    });
  });

  test('the backstop re-adds a missing column without backfilling', () async {
    final db = AppDatabase(
      setupDb(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_tanks'), contains('source_id'));
    expect((await sourceIds(db))['t1'], isNull);
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'dive_tanks'), contains('source_id'));
  });
}
