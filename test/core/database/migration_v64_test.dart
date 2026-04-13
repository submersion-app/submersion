import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v64 - delete orphaned diver data', () {
    /// Creates stub tables for every table the v64 migration touches.
    void createStubTables(dynamic rawDb) {
      for (final table in [
        'trips',
        'dive_sites',
        'equipment',
        'equipment_sets',
        'buddies',
        'certifications',
        'dive_centers',
        'tags',
        'tank_presets',
      ]) {
        rawDb.execute('''
          CREATE TABLE IF NOT EXISTS $table (
            id TEXT NOT NULL PRIMARY KEY,
            diver_id TEXT REFERENCES divers(id),
            created_at INTEGER NOT NULL DEFAULT 0,
            updated_at INTEGER NOT NULL DEFAULT 0
          )
        ''');
      }
    }

    NativeDatabase setupDb({
      required List<(String id, String name)> divers,
      List<(String id, String? diverId, String addr)> computers = const [],
      List<(String id, String? diverId)> dives = const [],
    }) {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 63');

          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_computers (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              name TEXT NOT NULL DEFAULT '',
              bluetooth_address TEXT,
              last_dive_fingerprint TEXT,
              last_download_timestamp INTEGER,
              dive_count INTEGER NOT NULL DEFAULT 0,
              is_favorite INTEGER NOT NULL DEFAULT 0,
              notes TEXT NOT NULL DEFAULT '',
              manufacturer TEXT, model TEXT, serial_number TEXT,
              firmware_version TEXT, connection_type TEXT,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT REFERENCES divers(id),
              dive_date_time INTEGER NOT NULL DEFAULT 0,
              notes TEXT NOT NULL DEFAULT '',
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute('''
            CREATE TABLE view_configs (
              id TEXT NOT NULL PRIMARY KEY,
              diver_id TEXT NOT NULL REFERENCES divers(id) ON DELETE CASCADE,
              view_mode TEXT NOT NULL,
              config_json TEXT NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          createStubTables(rawDb);

          for (final d in divers) {
            rawDb.execute(
              "INSERT INTO divers (id, name) VALUES ('${d.$1}', '${d.$2}')",
            );
          }
          for (final c in computers) {
            final dv = c.$2 == null ? 'NULL' : "'${c.$2}'";
            rawDb.execute(
              "INSERT INTO dive_computers (id, diver_id, name, bluetooth_address)"
              " VALUES ('${c.$1}', $dv, 'Computer', '${c.$3}')",
            );
          }
          for (final d in dives) {
            final dv = d.$2 == null ? 'NULL' : "'${d.$2}'";
            rawDb.execute(
              "INSERT INTO dives (id, diver_id) VALUES ('${d.$1}', $dv)",
            );
          }
        },
      );
    }

    test('deletes orphaned records and preserves owned records', () async {
      final nativeDb = setupDb(
        divers: [('sole-diver', 'Alice')],
        computers: [
          ('orphan-comp', null, 'AA:BB:CC:DD:EE:FF'),
          ('owned-comp', 'sole-diver', '11:22:33:44:55:66'),
        ],
        dives: [('orphan-dive', null), ('owned-dive', 'sole-diver')],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final comps = await db
          .customSelect('SELECT id FROM dive_computers')
          .get();
      expect(comps.map((r) => r.read<String>('id')), ['owned-comp']);

      final dvs = await db.customSelect('SELECT id FROM dives').get();
      expect(dvs.map((r) => r.read<String>('id')), ['owned-dive']);
    });

    test('deletes orphaned records with multiple divers', () async {
      final nativeDb = setupDb(
        divers: [('diver-a', 'Alice'), ('diver-b', 'Bob')],
        computers: [
          ('orphan-comp', null, 'AA:BB:CC:DD:EE:FF'),
          ('owned-comp', 'diver-a', '11:22:33:44:55:66'),
        ],
        dives: [('orphan-dive', null), ('owned-dive', 'diver-b')],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final comps = await db
          .customSelect('SELECT id FROM dive_computers')
          .get();
      expect(comps.map((r) => r.read<String>('id')), ['owned-comp']);

      final dvs = await db.customSelect('SELECT id FROM dives').get();
      expect(dvs.map((r) => r.read<String>('id')), ['owned-dive']);
    });

    test('no-op when no orphaned records exist', () async {
      final nativeDb = setupDb(
        divers: [('diver-a', 'Alice')],
        computers: [('owned-comp', 'diver-a', 'AA:BB:CC:DD:EE:FF')],
        dives: [('owned-dive', 'diver-a')],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final comps = await db
          .customSelect('SELECT id FROM dive_computers')
          .get();
      expect(comps, hasLength(1));
    });
  });
}
