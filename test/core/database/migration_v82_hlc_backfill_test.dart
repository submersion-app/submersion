import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Migration 82 recovers databases stranded by the v77 schema-version
/// collision: PR #302 shipped a v77 that only created the
/// idx_dives_diver_exittime index, while the HLC backfill independently
/// claimed v77. A database upgraded under the index-only v77 sits at
/// user_version >= 77 with no hlc columns -- the original v77 backfill is
/// gated `if (from < 77)` and gets skipped, leaving every sync UNION query
/// (SELECT MAX(hlc) FROM "equipment") failing at prepare time.
///
/// v82 re-runs the same PRAGMA-guarded ALTER so affected databases recover.
void main() {
  test(
    'v77+ -> v82 backfills hlc on equipment for collision-stranded dbs',
    () async {
      // Simulate the collision state: user_version = 77 (from the index-only
      // v77), but every HLC-target table is missing the hlc column.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 77');
          rawDb.execute(
            'CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute('CREATE TABLE dives (id TEXT NOT NULL PRIMARY KEY)');
          rawDb.execute(
            'CREATE TABLE dive_sites (id TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute(
            'CREATE TABLE settings (key TEXT NOT NULL PRIMARY KEY)',
          );
          rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL
          )
        ''');
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      Future<bool> hasHlc(String table) async {
        final cols = await db.customSelect("PRAGMA table_info('$table')").get();
        return cols.any((c) => c.read<String>('name') == 'hlc');
      }

      expect(
        await hasHlc('equipment'),
        isTrue,
        reason: 'v82 must backfill the column the v77 collision skipped',
      );
      expect(await hasHlc('dives'), isTrue);
      expect(await hasHlc('dive_sites'), isTrue);
      expect(await hasHlc('settings'), isTrue);
      expect(
        await hasHlc('sync_metadata'),
        isTrue,
        reason: 'the device clock is persisted in sync_metadata.hlc',
      );
    },
  );

  test('v82 is idempotent on databases that already have hlc', () async {
    // Healthy database: user_version = 81 with hlc already added by the v77
    // path. v82 must see hlc present and no-op (no "duplicate column" error).
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 81');
        rawDb.execute('''
          CREATE TABLE equipment (
            id TEXT NOT NULL PRIMARY KEY,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO equipment (id, hlc) "
          "VALUES ('eq-1', '000000000001000:000003:node-x')",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect("SELECT hlc FROM equipment WHERE id = 'eq-1'")
        .getSingle();
    expect(
      row.read<String?>('hlc'),
      '000000000001000:000003:node-x',
      reason: 'existing hlc values must survive the v82 no-op pass',
    );
  });

  test('v82 preserves existing rows on collision-stranded dbs', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 77');
        rawDb.execute('CREATE TABLE equipment (id TEXT NOT NULL PRIMARY KEY)');
        rawDb.execute(
          "INSERT INTO equipment (id) VALUES ('pre-existing-gear')",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT id, hlc FROM equipment WHERE id = 'pre-existing-gear'",
        )
        .getSingle();
    expect(row.read<String>('id'), 'pre-existing-gear');
    expect(
      row.read<String?>('hlc'),
      isNull,
      reason: 'backfilled rows start with null hlc (updatedAt fallback)',
    );
  });
}
