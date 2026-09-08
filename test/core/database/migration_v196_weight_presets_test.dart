import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';

/// v196 adds the reusable weighting-rig tables (issue #1609).

Future<Set<String>> _tables(AppDatabase db) async {
  final rows = await db
      .customSelect("SELECT name FROM sqlite_master WHERE type = 'table'")
      .get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

Future<Set<String>> _columns(AppDatabase db, String table) async {
  final rows = await db.customSelect("PRAGMA table_info('$table')").get();
  return rows.map((r) => r.read<String>('name')).toSet();
}

void main() {
  test('v196 is the current schema version and is in the ladder', () {
    // Renumbered from 192 then 195: main landed the transmitter-serial rung
    // (194) and the media-species-clock rung (195) while this branch was
    // open. As the newest rung this holds the exact assertion; older rung
    // tests relax to greaterThanOrEqualTo.
    expect(AppDatabase.currentSchemaVersion, 196);
    expect(AppDatabase.migrationVersions, contains(196));
  });

  test('a fresh database has both weight-preset tables', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final tables = await _tables(db);
    expect(tables, containsAll(['weight_presets', 'weight_preset_entries']));

    expect(
      await _columns(db, 'weight_presets'),
      containsAll(['id', 'diver_id', 'display_name', 'notes', 'hlc']),
    );
    expect(
      await _columns(db, 'weight_preset_entries'),
      containsAll([
        'id',
        'preset_id',
        'weight_type',
        'amount_kg',
        'sort_order',
      ]),
    );
  });

  test('a database stranded before v196 gains the tables', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 195');
        rawDb.execute('''
          CREATE TABLE divers (
            id TEXT NOT NULL PRIMARY KEY,
            name TEXT NOT NULL,
            created_at INTEGER NOT NULL,
            updated_at INTEGER NOT NULL
          )
        ''');
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final tables = await _tables(db);
    expect(tables, containsAll(['weight_presets', 'weight_preset_entries']));
  });

  test('deleting a preset cascades its entries', () async {
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    await db.customStatement(
      "INSERT INTO weight_presets (id, display_name, created_at, updated_at) "
      "VALUES ('p1', 'Drysuit', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO weight_preset_entries "
      "(id, preset_id, weight_type, amount_kg, created_at) "
      "VALUES ('e1', 'p1', 'belt', 3.0, 1)",
    );

    await db.customStatement("DELETE FROM weight_presets WHERE id = 'p1'");

    final left = await db
        .customSelect('SELECT COUNT(*) AS n FROM weight_preset_entries')
        .getSingle();
    expect(left.read<int>('n'), 0);
  });
}
