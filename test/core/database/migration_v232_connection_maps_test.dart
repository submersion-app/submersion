import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v232: saved connection maps and the sightings dive index
/// (issue #2322, spec Revision 2).
void main() {
  /// A v231 database with the stub parents earlier backstops look for, a
  /// sightings table without the index, and no connection_maps.
  NativeDatabase setupDb({int userVersion = 231, bool withDivers = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        if (withDivers) {
          rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        }
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          'CREATE TABLE sightings (id TEXT NOT NULL PRIMARY KEY, '
          'dive_id TEXT NOT NULL, species_id TEXT NOT NULL)',
        );
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
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<List<Map<String, Object?>>> tableInfo(
    AppDatabase db,
    String table,
  ) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return [
      for (final c in cols)
        {
          'name': c.data['name'],
          'type': c.data['type'],
          'notnull': c.data['notnull'],
          'dflt_value': c.data['dflt_value'],
          'pk': c.data['pk'],
        },
    ];
  }

  Future<String?> ddlOf(AppDatabase db, String type, String name) async {
    final rows = await db
        .customSelect(
          'SELECT sql FROM sqlite_master WHERE type = ? AND name = ?',
          variables: [Variable<String>(type), Variable<String>(name)],
        )
        .get();
    return rows.isEmpty ? null : rows.single.read<String?>('sql');
  }

  Future<Set<String>> indexNames(AppDatabase db) async {
    final rows = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type = 'index'")
        .get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v232 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 232);
    expect(AppDatabase.migrationVersions, contains(232));
    expect(AppDatabase.migrationStepCount(231), 1);
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds the connection_maps table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await columnsOf(db, 'connection_maps'),
      containsAll(<String>[
        'id',
        'diver_id',
        'name',
        'spec',
        'sort_order',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('a deleted diver takes their maps with them', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(
      await ddlOf(db, 'table', 'connection_maps'),
      contains('REFERENCES divers (id) ON DELETE CASCADE'),
    );
  });

  test('creates the maps index and the sightings dive index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();
    expect(
      await indexNames(db),
      containsAll(<String>[
        'idx_connection_maps_diver',
        'idx_sightings_dive_id',
      ]),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);
    expect(
      await tableInfo(upgraded, 'connection_maps'),
      await tableInfo(fresh, 'connection_maps'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'connection_maps'),
      await ddlOf(fresh, 'table', 'connection_maps'),
    );
    await fresh.customSelect('SELECT 1').get();
    expect(await indexNames(fresh), contains('idx_sightings_dive_id'));
  });

  test(
    'a database stamped v232 without the table heals in beforeOpen',
    () async {
      final db = AppDatabase(setupDb(userVersion: 232));
      addTearDown(db.close);
      expect(await columnsOf(db, 'connection_maps'), contains('spec'));
    },
  );

  test('a fixture without divers skips the table', () async {
    final db = AppDatabase(setupDb(withDivers: false));
    addTearDown(db.close);
    expect(await columnsOf(db, 'connection_maps'), isEmpty);
  });
}
