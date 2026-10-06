import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v267: custom certification agencies and levels (issue #690).
/// Table-and-index rung with no data migration: stored agency and level text
/// are built-in enum names, which stay valid ids.
void main() {
  /// A database at [userVersion] without the custom tables. Minimal parents,
  /// as the v234 fixture: the beforeOpen backstops heal every older rung.
  NativeDatabase setupDb({int userVersion = 261, bool withDivers = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        if (withDivers) {
          rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        }
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute('''
          CREATE TABLE certifications (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            agency TEXT NOT NULL,
            level TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO certifications (id, name, agency, level) "
          "VALUES ('c1', 'Card', 'padi', 'openWater')",
        );
      },
    );
  }

  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
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

  const agencyColumns = {
    'id',
    'diver_id',
    'name',
    'color_argb',
    'is_shared',
    'created_at',
    'updated_at',
    'hlc',
  };
  const levelColumns = {
    'id',
    'diver_id',
    'agency_id',
    'name',
    'is_progression',
    'sort_order',
    'is_shared',
    'created_at',
    'updated_at',
    'hlc',
  };

  test('v267 is at or below the current schema version and in the ladder', () {
    // Relaxed once v269 (diver_settings.hidden_built_in_ids, #401) landed on
    // top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(267));
    expect(AppDatabase.migrationVersions, contains(267));
    expect(
      AppDatabase.migrationStepCount(266),
      AppDatabase.migrationStepCount(267) + 1,
    );
    // Additive rung: new synced tables never raise the floor.
    expect(AppDatabase.minimumCompatibleSchemaVersion, lessThan(267));
  });

  test('a v261 database gains both tables and the index', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    expect(await columnsOf(db, 'custom_certification_agencies'), agencyColumns);
    expect(await columnsOf(db, 'custom_certification_levels'), levelColumns);
    expect(
      await ddlOf(db, 'index', 'idx_custom_certification_levels_agency'),
      isNotNull,
    );
  });

  test('existing certification text is untouched', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    final row = await db
        .customSelect(
          "SELECT agency, level FROM certifications WHERE id = 'c1'",
        )
        .getSingle();
    expect(row.read<String>('agency'), 'padi');
    expect(row.read<String>('level'), 'openWater');
  });

  test('owners reference divers with no ON DELETE action', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);
    for (final table in [
      'custom_certification_agencies',
      'custom_certification_levels',
    ]) {
      final ddl = await ddlOf(db, 'table', table);
      expect(ddl, contains('REFERENCES divers (id)'), reason: table);
      expect(ddl, isNot(contains('ON DELETE')), reason: table);
    }
  });

  test('the beforeOpen backstop heals a database already at 267', () async {
    final db = AppDatabase(setupDb(userVersion: 267));
    addTearDown(db.close);
    expect(await columnsOf(db, 'custom_certification_agencies'), agencyColumns);
    expect(await columnsOf(db, 'custom_certification_levels'), levelColumns);
  });

  test('a fixture without divers gains no dangling tables', () async {
    final db = AppDatabase(setupDb(withDivers: false));
    addTearDown(db.close);
    expect(await ddlOf(db, 'table', 'custom_certification_agencies'), isNull);
  });
}
