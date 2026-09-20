import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v221: rental gear memory, the dive_center_gear_notes table
/// (issue #2075).
void main() {
  /// A v219 database with the two parents the new table references and
  /// the tables the beforeOpen backstops touch, and no
  /// dive_center_gear_notes.
  NativeDatabase setupDb({int userVersion = 219, bool withDiveCenters = true}) {
    return NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = $userVersion');
        rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
        rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        if (withDiveCenters) {
          rawDb.execute('CREATE TABLE dive_centers (id TEXT PRIMARY KEY)');
        }
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

  test('v221 is the current schema version and is in the ladder', () {
    // The newest rung owns the exact assertion; relax it to
    // greaterThanOrEqualTo when the next one lands.
    expect(AppDatabase.currentSchemaVersion, 221);
    expect(AppDatabase.migrationVersions, contains(221));
    expect(AppDatabase.migrationStepCount(220), 1);
    // Additive rung: the sync compatibility floor must not move.
    expect(AppDatabase.minimumCompatibleSchemaVersion, 210);
  });

  test('adds the dive_center_gear_notes table', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    expect(
      await columnsOf(db, 'dive_center_gear_notes'),
      containsAll(<String>[
        'id',
        'dive_center_id',
        'gear_type',
        'label',
        'size',
        'verdict',
        'lead_adjustment_kg',
        'volume_liters',
        'note',
        'dive_id',
        'noted_at',
        'created_at',
        'updated_at',
        'hlc',
      ]),
    );
  });

  test('the table cascades from its center and detaches from a dive', () async {
    final db = AppDatabase(setupDb());
    addTearDown(db.close);

    final ddl = await ddlOf(db, 'table', 'dive_center_gear_notes');
    expect(ddl, contains('REFERENCES dive_centers (id) ON DELETE CASCADE'));
    expect(ddl, contains('REFERENCES dives (id) ON DELETE SET NULL'));
  });

  test('a fresh database matches the upgraded one', () async {
    final upgraded = AppDatabase(setupDb());
    addTearDown(upgraded.close);
    final fresh = AppDatabase(NativeDatabase.memory());
    addTearDown(fresh.close);

    expect(
      await tableInfo(upgraded, 'dive_center_gear_notes'),
      await tableInfo(fresh, 'dive_center_gear_notes'),
    );
    expect(
      await ddlOf(upgraded, 'table', 'dive_center_gear_notes'),
      await ddlOf(fresh, 'table', 'dive_center_gear_notes'),
    );
  });

  test(
    'a database stamped v221 without the table heals in beforeOpen',
    () async {
      // A parallel branch that claimed 221 first carries a device past the
      // rung; the beforeOpen backstop must build what the rung would have.
      final db = AppDatabase(setupDb(userVersion: 221));
      addTearDown(db.close);

      expect(
        await columnsOf(db, 'dive_center_gear_notes'),
        contains('dive_center_id'),
      );
    },
  );

  test('a fixture without dive_centers skips the table', () async {
    final db = AppDatabase(setupDb(withDiveCenters: false));
    addTearDown(db.close);

    expect(await columnsOf(db, 'dive_center_gear_notes'), isEmpty);
  });
}
