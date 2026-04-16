import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  group('Migration v66 - raw dive data columns and FK rebuild', () {
    /// Creates an in-memory database at v65 with the tables the v66 migration
    /// touches: dives, dive_computers, and dive_data_sources.
    ///
    /// The dive_data_sources schema includes all columns through v55 but
    /// none of the v66 additions (raw_data, raw_fingerprint, etc.).
    NativeDatabase setupDb({
      List<(String id, String diverId)> dives = const [],
      List<(String id, String? diverId)> computers = const [],
      List<
            (
              String id,
              String diveId,
              String? computerId,
              int importedAt,
              int createdAt,
            )
          >
          dataSources =
          const [],
    }) {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 65');

          rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
          rawDb.execute(
            "INSERT INTO divers (id, name) VALUES ('diver1', 'Alice')",
          );

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

          // v65 schema: original v53 columns + v54 renames/additions.
          // FK on computer_id is NO ACTION (the original default).
          rawDb.execute('''
            CREATE TABLE dive_data_sources (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              computer_id TEXT REFERENCES dive_computers(id),
              is_primary INTEGER NOT NULL DEFAULT 0,
              computer_model TEXT,
              computer_serial TEXT,
              source_format TEXT,
              source_file_name TEXT,
              source_file_format TEXT,
              max_depth REAL,
              avg_depth REAL,
              duration INTEGER,
              water_temp REAL,
              entry_time INTEGER,
              exit_time INTEGER,
              max_ascent_rate REAL,
              max_descent_rate REAL,
              surface_interval INTEGER,
              cns REAL,
              otu REAL,
              deco_algorithm TEXT,
              gradient_factor_low INTEGER,
              gradient_factor_high INTEGER,
              imported_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute('''
            CREATE INDEX IF NOT EXISTS idx_dive_data_sources_dive_id
            ON dive_data_sources(dive_id)
          ''');

          for (final d in dives) {
            rawDb.execute(
              "INSERT INTO dives (id, diver_id) VALUES ('${d.$1}', '${d.$2}')",
            );
          }
          for (final c in computers) {
            final dv = c.$2 == null ? 'NULL' : "'${c.$2}'";
            rawDb.execute(
              "INSERT INTO dive_computers (id, diver_id, name)"
              " VALUES ('${c.$1}', $dv, 'Computer')",
            );
          }
          for (final ds in dataSources) {
            final cId = ds.$3 == null ? 'NULL' : "'${ds.$3}'";
            rawDb.execute(
              "INSERT INTO dive_data_sources"
              " (id, dive_id, computer_id, is_primary,"
              "  computer_model, source_format, imported_at, created_at)"
              " VALUES ('${ds.$1}', '${ds.$2}', $cId, 1,"
              "  'Perdix', 'dc', ${ds.$4}, ${ds.$5})",
            );
          }
        },
      );
    }

    test('adds new columns to dive_data_sources', () async {
      final nativeDb = setupDb(
        dives: [('dive1', 'diver1')],
        computers: [('comp1', 'diver1')],
        dataSources: [('ds1', 'dive1', 'comp1', 1000, 1000)],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      // Verify new columns exist by querying PRAGMA table_info.
      final columns = await db
          .customSelect("PRAGMA table_info('dive_data_sources')")
          .get();
      final colNames = columns.map((c) => c.read<String>('name')).toSet();

      expect(colNames, contains('raw_data'));
      expect(colNames, contains('raw_fingerprint'));
      expect(colNames, contains('descriptor_vendor'));
      expect(colNames, contains('descriptor_product'));
      expect(colNames, contains('descriptor_model'));
      expect(colNames, contains('libdivecomputer_version'));
      expect(colNames, contains('last_parsed_at'));
    });

    test('preserves existing data through table rebuild', () async {
      final nativeDb = setupDb(
        dives: [('dive1', 'diver1')],
        computers: [('comp1', 'diver1')],
        dataSources: [('ds1', 'dive1', 'comp1', 2000, 3000)],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            'SELECT id, dive_id, computer_id, is_primary,'
            ' computer_model, source_format, imported_at, created_at'
            ' FROM dive_data_sources',
          )
          .get();
      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.read<String>('id'), 'ds1');
      expect(row.read<String>('dive_id'), 'dive1');
      expect(row.read<String>('computer_id'), 'comp1');
      expect(row.read<int>('is_primary'), 1);
      expect(row.read<String>('computer_model'), 'Perdix');
      expect(row.read<String>('source_format'), 'dc');
      expect(row.read<int>('imported_at'), 2000);
      expect(row.read<int>('created_at'), 3000);
    });

    test('new columns default to NULL after migration', () async {
      final nativeDb = setupDb(
        dives: [('dive1', 'diver1')],
        computers: [('comp1', 'diver1')],
        dataSources: [('ds1', 'dive1', 'comp1', 1000, 1000)],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            'SELECT raw_data, raw_fingerprint, descriptor_vendor,'
            ' descriptor_product, descriptor_model,'
            ' libdivecomputer_version, last_parsed_at'
            ' FROM dive_data_sources',
          )
          .get();
      expect(rows, hasLength(1));
      final row = rows.first;
      expect(row.readNullable<Uint8List>('raw_data'), isNull);
      expect(row.readNullable<Uint8List>('raw_fingerprint'), isNull);
      expect(row.readNullable<String>('descriptor_vendor'), isNull);
      expect(row.readNullable<String>('descriptor_product'), isNull);
      expect(row.readNullable<int>('descriptor_model'), isNull);
      expect(row.readNullable<String>('libdivecomputer_version'), isNull);
      expect(row.readNullable<int>('last_parsed_at'), isNull);
    });

    test('ON DELETE SET NULL on computer_id after FK rebuild', () async {
      final nativeDb = setupDb(
        dives: [('dive1', 'diver1')],
        computers: [('comp1', 'diver1')],
        dataSources: [('ds1', 'dive1', 'comp1', 1000, 1000)],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      // Verify the data source references the computer before deletion.
      var rows = await db
          .customSelect(
            "SELECT computer_id FROM dive_data_sources WHERE id = 'ds1'",
          )
          .get();
      expect(rows.first.read<String>('computer_id'), 'comp1');

      // Delete the dive computer.
      await db.customStatement("DELETE FROM dive_computers WHERE id = 'comp1'");

      // The FK should now be NULL (ON DELETE SET NULL).
      rows = await db
          .customSelect(
            "SELECT computer_id FROM dive_data_sources WHERE id = 'ds1'",
          )
          .get();
      expect(rows.first.readNullable<String>('computer_id'), isNull);
    });

    test('multiple data sources preserved through rebuild', () async {
      final nativeDb = setupDb(
        dives: [('dive1', 'diver1'), ('dive2', 'diver1')],
        computers: [('comp1', 'diver1'), ('comp2', 'diver1')],
        dataSources: [
          ('ds1', 'dive1', 'comp1', 1000, 1000),
          ('ds2', 'dive1', 'comp2', 2000, 2000),
          ('ds3', 'dive2', null, 3000, 3000),
        ],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      final rows = await db
          .customSelect(
            'SELECT id, dive_id, computer_id'
            ' FROM dive_data_sources ORDER BY id',
          )
          .get();
      expect(rows, hasLength(3));
      expect(rows[0].read<String>('id'), 'ds1');
      expect(rows[0].read<String>('dive_id'), 'dive1');
      expect(rows[0].read<String>('computer_id'), 'comp1');

      expect(rows[1].read<String>('id'), 'ds2');
      expect(rows[1].read<String>('dive_id'), 'dive1');
      expect(rows[1].read<String>('computer_id'), 'comp2');

      expect(rows[2].read<String>('id'), 'ds3');
      expect(rows[2].read<String>('dive_id'), 'dive2');
      expect(rows[2].readNullable<String>('computer_id'), isNull);
    });

    test(
      'migration succeeds when new columns already exist (re-run guard)',
      () async {
        // Simulate a database where the v66 columns were already added (e.g.
        // partial migration or re-run). The PRAGMA table_info guard should
        // skip the ALTER TABLE statements without error.
        final nativeDb = NativeDatabase.memory(
          setup: (rawDb) {
            rawDb.execute('PRAGMA foreign_keys = ON');
            rawDb.execute('PRAGMA user_version = 65');

            rawDb.execute('''
            CREATE TABLE divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL DEFAULT 0,
              updated_at INTEGER NOT NULL DEFAULT 0
            )
          ''');
            rawDb.execute(
              "INSERT INTO divers (id, name) VALUES ('diver1', 'Alice')",
            );

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

            // v65 schema WITH the v66 columns already present -- simulates
            // a partial migration where ADD COLUMN succeeded but the table
            // rebuild did not complete.
            rawDb.execute('''
            CREATE TABLE dive_data_sources (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              computer_id TEXT REFERENCES dive_computers(id),
              is_primary INTEGER NOT NULL DEFAULT 0,
              computer_model TEXT,
              computer_serial TEXT,
              source_format TEXT,
              source_file_name TEXT,
              source_file_format TEXT,
              max_depth REAL,
              avg_depth REAL,
              duration INTEGER,
              water_temp REAL,
              entry_time INTEGER,
              exit_time INTEGER,
              max_ascent_rate REAL,
              max_descent_rate REAL,
              surface_interval INTEGER,
              cns REAL,
              otu REAL,
              deco_algorithm TEXT,
              gradient_factor_low INTEGER,
              gradient_factor_high INTEGER,
              imported_at INTEGER NOT NULL,
              created_at INTEGER NOT NULL,
              raw_data BLOB,
              raw_fingerprint BLOB,
              descriptor_vendor TEXT,
              descriptor_product TEXT,
              descriptor_model INTEGER,
              libdivecomputer_version TEXT,
              last_parsed_at INTEGER
            )
          ''');

            rawDb.execute(
              "INSERT INTO dives (id, diver_id) VALUES ('dive1', 'diver1')",
            );
            rawDb.execute(
              "INSERT INTO dive_computers (id, diver_id, name)"
              " VALUES ('comp1', 'diver1', 'Computer')",
            );
            rawDb.execute(
              "INSERT INTO dive_data_sources"
              " (id, dive_id, computer_id, is_primary,"
              "  source_format, imported_at, created_at,"
              "  raw_data, descriptor_vendor)"
              " VALUES ('ds1', 'dive1', 'comp1', 1,"
              "  'dc', 1000, 1000, X'0102', 'Shearwater')",
            );
          },
        );

        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        // Migration should complete without error
        final columns = await db
            .customSelect("PRAGMA table_info('dive_data_sources')")
            .get();
        final colNames = columns.map((c) => c.read<String>('name')).toSet();

        // All v66 columns should still be present
        expect(colNames, contains('raw_data'));
        expect(colNames, contains('raw_fingerprint'));
        expect(colNames, contains('descriptor_vendor'));
        expect(colNames, contains('descriptor_product'));
        expect(colNames, contains('descriptor_model'));
        expect(colNames, contains('libdivecomputer_version'));
        expect(colNames, contains('last_parsed_at'));

        // Pre-existing data should be preserved through the rebuild
        final rows = await db
            .customSelect(
              'SELECT id, descriptor_vendor, raw_data FROM dive_data_sources',
            )
            .get();
        expect(rows, hasLength(1));
        expect(rows.first.read<String>('id'), 'ds1');
        expect(rows.first.read<String>('descriptor_vendor'), 'Shearwater');
        expect(rows.first.read<Uint8List>('raw_data'), isNotNull);
      },
    );

    test('cascade delete on dive_id still works after rebuild', () async {
      final nativeDb = setupDb(
        dives: [('dive1', 'diver1')],
        computers: [('comp1', 'diver1')],
        dataSources: [('ds1', 'dive1', 'comp1', 1000, 1000)],
      );

      final db = AppDatabase(nativeDb);
      addTearDown(db.close);

      // Deleting the dive should cascade-delete the data source.
      await db.customStatement("DELETE FROM dives WHERE id = 'dive1'");

      final rows = await db
          .customSelect('SELECT id FROM dive_data_sources')
          .get();
      expect(rows, isEmpty);
    });
  });
}
