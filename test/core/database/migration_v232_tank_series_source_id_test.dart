import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v232: tank_pressure_series.source_id (issue #2440). Two
/// file-imported sources of one dive both carry a null computer, so their
/// series of the same cylinder could not be told apart.
void main() {
  /// A v231 database with the tables the rung and the beforeOpen backstops
  /// touch, and tank series for three dives:
  ///
  /// * d1 has one source: its series takes that source.
  /// * d2 has two sources on different computers: each series takes the
  ///   source of the computer that recorded it.
  /// * d3 has two file-imported sources (no computer): nothing tells the
  ///   series apart, so they stay unattributed.
  NativeDatabase setupDb({int userVersion = 231}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE tags (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT,
            name TEXT NOT NULL,
            color TEXT,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL,
            hlc TEXT,
            applies_to_dives INTEGER NOT NULL DEFAULT 1
              CHECK (applies_to_dives IN (0, 1)),
            applies_to_sites INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_sites IN (0, 1)),
            applies_to_equipment INTEGER NOT NULL DEFAULT 0
              CHECK (applies_to_equipment IN (0, 1))
          )
        ''');
        rawDb.execute('CREATE TABLE media (id TEXT PRIMARY KEY, hlc TEXT)');
        rawDb.execute('''
          CREATE TABLE dive_data_sources (
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
            computer_id TEXT
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
          INSERT INTO tank_pressure_series (id, dive_id, tank_id, computer_id)
          VALUES
            ('s1', 'd1', 't1', NULL),
            ('s2a', 'd2', 't2', 'c1'),
            ('s2b', 'd2', 't2', 'c2'),
            ('s3a', 'd3', 't3', NULL),
            ('s3b', 'd3', 't3', NULL)
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
        .customSelect('SELECT id, source_id FROM tank_pressure_series')
        .get();
    return {
      for (final r in rows) r.read<String>('id'): r.read<String?>('source_id'),
    };
  }

  test('v232 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 232);
    expect(AppDatabase.migrationVersions, contains(232));
    expect(AppDatabase.migrationStepCount(231), 1);
  });

  test('the column is additive and did not move the sync floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('upgrading from v231 attributes the unambiguous series', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await columnsOf(db, 'tank_pressure_series'), contains('source_id'));
    expect(await sourceIds(db), {
      's1': 'src1',
      's2a': 'src2a',
      's2b': 'src2b',
      's3a': null,
      's3b': null,
    });
  });

  test('the backstop re-adds a missing column without backfilling', () async {
    final db = AppDatabase(
      setupDb(userVersion: AppDatabase.currentSchemaVersion),
    );
    addTearDown(db.close);
    expect(await columnsOf(db, 'tank_pressure_series'), contains('source_id'));
    expect((await sourceIds(db))['s1'], isNull);
  });

  test('a fresh database has the column', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'tank_pressure_series'), contains('source_id'));
  });
}
