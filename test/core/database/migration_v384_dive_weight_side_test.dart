import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';

/// v384 adds `dive_weights.side` (issue #5028): which side of the diver a
/// weight is carried on, for the trim figure's roll. Nullable with no
/// backfill: null means both sides, split evenly, so every existing weight
/// upgrades unchanged and the floor holds.
void main() {
  test('v384 is in the migration ladder', () {
    expect(AppDatabase.currentSchemaVersion, greaterThanOrEqualTo(384));
    expect(AppDatabase.migrationVersions, contains(384));
  });

  test('the new column kept the floor', () {
    expect(AppDatabase.minimumCompatibleSchemaVersion, isNot(384));
  });

  test('a fresh database has dive_weights.side, nullable TEXT', () async {
    final db = AppDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    addTearDown(db.close);

    final cols = await db
        .customSelect("PRAGMA table_info('dive_weights')")
        .get();
    final column = cols.firstWhere((c) => c.read<String>('name') == 'side');
    expect(column.read<int>('notnull'), 0);
    expect(column.read<String>('type'), 'TEXT');
  });

  /// The rung and the beforeOpen backstop share one idempotent helper, so
  /// this holds whichever runs first; the ladder entry above pins the rung.
  test('an existing weight upgrades to both sides (null)', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 382');
        rawDb.execute('''
          CREATE TABLE dive_weights (
            id TEXT NOT NULL PRIMARY KEY,
            dive_id TEXT NOT NULL,
            weight_type TEXT NOT NULL,
            amount_kg REAL NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            label TEXT NOT NULL DEFAULT '',
            created_at INTEGER NOT NULL,
            hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO dive_weights (id, dive_id, weight_type, amount_kg, "
          "created_at) VALUES ('w1', 'd1', 'integrated', 4, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT side FROM dive_weights WHERE id = 'w1'")
        .getSingle();
    expect(row.readNullable<String>('side'), isNull);
  });

  test(
    'a fresh database has weight_preset_entries.side, nullable TEXT',
    () async {
      final db = AppDatabase(
        NativeDatabase.memory(setup: registerAppSqlFunctions),
      );
      addTearDown(db.close);

      final cols = await db
          .customSelect("PRAGMA table_info('weight_preset_entries')")
          .get();
      final column = cols.firstWhere((c) => c.read<String>('name') == 'side');
      expect(column.read<int>('notnull'), 0);
      expect(column.read<String>('type'), 'TEXT');
    },
  );

  test('an existing preset entry upgrades to both sides (null)', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 382');
        rawDb.execute('''
          CREATE TABLE weight_preset_entries (
            id TEXT NOT NULL PRIMARY KEY,
            preset_id TEXT NOT NULL,
            weight_type TEXT NOT NULL,
            amount_kg REAL NOT NULL,
            notes TEXT NOT NULL DEFAULT '',
            label TEXT NOT NULL DEFAULT '',
            sort_order INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            hlc TEXT)
        ''');
        rawDb.execute(
          "INSERT INTO weight_preset_entries (id, preset_id, weight_type, "
          "amount_kg, created_at) VALUES ('e1', 'p1', 'trimWeights', 2, 0)",
        );
      },
    );
    final db = AppDatabase(nativeDb);
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT side FROM weight_preset_entries WHERE id = 'e1'")
        .getSingle();
    expect(row.readNullable<String>('side'), isNull);
  });
}
