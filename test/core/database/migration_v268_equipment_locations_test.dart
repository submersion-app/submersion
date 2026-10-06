import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Schema v268: equipment locations and their move log.
void main() {
  Future<Set<String>> columnsOf(AppDatabase db, String table) async {
    final cols = await db.customSelect("PRAGMA table_info('$table')").get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  Future<Set<String>> indexesOf(AppDatabase db, String table) async {
    final rows = await db.customSelect("PRAGMA index_list('$table')").get();
    return rows.map((r) => r.read<String>('name')).toSet();
  }

  test('v268 is at or below the current schema version and in the ladder', () {
    // Relaxed once v269 (diver_settings.hidden_built_in_ids, #401) landed
    // on top; the newest rung owns the exact assertions.
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(268));
    expect(AppDatabase.migrationVersions, contains(268));
    expect(
      AppDatabase.migrationStepCount(267),
      AppDatabase.migrationStepCount(268) + 1,
    );
  });

  test('a fresh database has both tables and their indexes', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_locations'), {
      'id',
      'diver_id',
      'name',
      'kind',
      'notes',
      'is_archived',
      'created_at',
      'updated_at',
      'hlc',
    });
    expect(await columnsOf(db, 'equipment_location_moves'), {
      'id',
      'equipment_id',
      'location_id',
      'moved_at',
      'note',
      'created_at',
      'hlc',
    });
    expect(
      await indexesOf(db, 'equipment_location_moves'),
      containsAll([
        'idx_equipment_location_moves_equipment',
        'idx_equipment_location_moves_location',
      ]),
    );
  });

  test('beforeOpen creates the tables on a file already at 268 without '
      'them', () async {
    // A database that reached 268 through a parallel branch's rung, or by
    // restore, never runs this rung: the backstop must heal it.
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 268');
          rawDb.execute('CREATE TABLE divers (id TEXT PRIMARY KEY)');
          rawDb.execute('CREATE TABLE dive_sites (id TEXT PRIMARY KEY)');
          rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
          );
        },
      ),
    );
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_locations'), contains('kind'));
    expect(
      await columnsOf(db, 'equipment_location_moves'),
      contains('moved_at'),
    );
  });

  test('the rung skips a partial fixture without the parent tables', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 268');
          rawDb.execute('CREATE TABLE dives (id TEXT PRIMARY KEY)');
        },
      ),
    );
    addTearDown(db.close);
    expect(await columnsOf(db, 'equipment_locations'), isEmpty);
  });
}
