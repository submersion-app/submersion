import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v228: cylinder fill history, the cylinder_fills table
/// (issue #2334).
void main() {
  /// A v227 database with the two parents the new table references and no
  /// cylinder_fills.
  NativeDatabase setupDb({int userVersion = 227, bool withEquipment = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        if (withEquipment) {
          rawDb.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
          );
        }
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

  test('v228 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 228);
    expect(AppDatabase.migrationVersions, contains(228));
    expect(AppDatabase.migrationStepCount(227), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 224);
  });

  test('adds the cylinder_fills table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'cylinder_fills'),
      containsAll(<String>[
        'id',
        'diver_id',
        'passport_id',
        'equipment_id',
        'filled_at',
        'o2_percent',
        'he_percent',
        'pressure_bar',
        'temperature_c',
        'analyzer',
        'station_name',
        'station_key',
        'signed_record',
        'source',
        'notes',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('a deleted cylinder clears the link instead of failing on it', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final ddl = await ddlOf(db, 'table', 'cylinder_fills');
    expect(ddl, contains('REFERENCES equipment (id) ON DELETE SET NULL'));
  });

  test('creates both lookup indexes', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    await db.customSelect('SELECT 1').get();

    expect(
      await indexNames(db),
      containsAll(<String>[
        'idx_cylinder_fills_passport',
        'idx_cylinder_fills_equipment',
      ]),
    );
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await tableInfo(upgraded, 'cylinder_fills'),
      await tableInfo(fresh, 'cylinder_fills'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'cylinder_fills'),
      await ddlOf(fresh, 'table', 'cylinder_fills'),
    );
  });

  test(
    'a database stamped v228 without the table heals in beforeOpen',
    () async {
      final db = AppDatabase(setupDb(userVersion: 228));
      addTearDown(db.close);

      expect(await columnsOf(db, 'cylinder_fills'), contains('passport_id'));
    },
  );

  test('a fixture without equipment skips the table', () async {
    final db = AppDatabase(setupDb(withEquipment: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'cylinder_fills'), isEmpty);
  });
}
