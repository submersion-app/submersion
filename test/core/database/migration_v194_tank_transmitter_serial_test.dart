import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Pre-v194 dive_tanks shape: no transmitter serial. Only the columns the
/// rung and its assertions touch, mirroring the other migration fixtures.
const _preV194DiveTanks = '''
  CREATE TABLE dive_tanks (
    id TEXT NOT NULL PRIMARY KEY,
    dive_id TEXT NOT NULL,
    o2_percent REAL NOT NULL DEFAULT 21.0,
    he_percent REAL NOT NULL DEFAULT 0.0,
    tank_order INTEGER NOT NULL DEFAULT 0,
    computer_id TEXT
  )
''';

void main() {
  test('v194 adds dive_tanks.transmitter_serial, preserving rows', () async {
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 193');
        rawDb.execute(_preV194DiveTanks);
        rawDb.execute(
          "INSERT INTO dive_tanks (id, dive_id, o2_percent, computer_id) "
          "VALUES ('t1', 'd1', 32.0, 'dc1')",
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('dive_tanks')").get();
    expect(
      cols.map((c) => c.read<String>('name')),
      contains('transmitter_serial'),
    );

    // The rung is column-only: an existing tank keeps its attribution and
    // reads back with no transmitter, never an invented one.
    final row = await db
        .customSelect(
          "SELECT computer_id, transmitter_serial FROM dive_tanks "
          "WHERE id = 't1'",
        )
        .getSingle();
    expect(row.data['computer_id'], 'dc1');
    expect(row.data['transmitter_serial'], isNull);
  });

  test('migration list includes v194 and schema is exactly 194', () {
    // The newest rung owns the exact assertion; relax to
    // greaterThanOrEqualTo when the next rung lands.
    expect(AppDatabase.currentSchemaVersion, 194);
    expect(AppDatabase.migrationVersions, contains(194));
  });

  test('v194 is idempotent when transmitter_serial already exists', () async {
    // An interrupted upgrade, or a database that reached this version from a
    // parallel branch, leaves the column already added. The PRAGMA guard
    // must skip the ALTER rather than fail on a duplicate column.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 193');
        rawDb.execute(_preV194DiveTanks);
        rawDb.execute(
          'ALTER TABLE dive_tanks ADD COLUMN transmitter_serial TEXT',
        );
      },
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    final cols = await db.customSelect("PRAGMA table_info('dive_tanks')").get();
    final names = cols.map((c) => c.read<String>('name')).toList();
    expect(names.where((n) => n == 'transmitter_serial'), hasLength(1));
  });

  test('v194 is a no-op when the dive_tanks table is absent', () async {
    // Minimal migration fixtures build only the tables their rung touches,
    // so the helper must self-guard rather than throw on a missing table.
    final nativeDb = NativeDatabase.memory(
      setup: (rawDb) => rawDb.execute('PRAGMA user_version = 193'),
    );

    final db = AppDatabase(nativeDb);
    addTearDown(() => db.close());

    // Reaching a query at all means the upgrade ran to completion.
    final tables = await db
        .customSelect(
          "SELECT name FROM sqlite_master WHERE type = 'table' "
          "AND name = 'dive_tanks'",
        )
        .get();
    expect(tables, isEmpty);
  });

  test(
    'beforeOpen backstop adds the column to a v194 database that lacks it',
    () async {
      // A database that arrives by restore or sync-adopt already stamped 194
      // never runs onUpgrade; the backstop must still add the column.
      final nativeDb = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 194');
          rawDb.execute(_preV194DiveTanks);
        },
      );

      final db = AppDatabase(nativeDb);
      addTearDown(() => db.close());

      final cols = await db
          .customSelect("PRAGMA table_info('dive_tanks')")
          .get();
      expect(
        cols.map((c) => c.read<String>('name')),
        contains('transmitter_serial'),
      );
    },
  );
}
