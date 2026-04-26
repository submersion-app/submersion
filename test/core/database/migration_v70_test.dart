import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

import 'test_fixtures.dart';

void main() {
  group('Migration v70 - source_uuid on dive_data_sources', () {
    /// Creates an in-memory database at v69 (pre-migration) with the
    /// dive_data_sources table the v70 migration touches.
    ///
    /// The dive_data_sources schema matches the post-v66 layout (final v69
    /// state) with all columns present before v70 -- no source_uuid column.
    NativeDatabase setupDb() {
      return NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 69');

          // Minimal parent tables referenced by dive_data_sources foreign keys.
          // dive_data_sources references dives(id) and dive_computers(id).
          rawDb.execute('''
            CREATE TABLE dives (
              id TEXT NOT NULL PRIMARY KEY
            )
          ''');
          rawDb.execute('''
            CREATE TABLE dive_computers (
              id TEXT NOT NULL PRIMARY KEY
            )
          ''');

          // v69 schema: all columns present before v70 -- no source_uuid.
          // Matches the layout produced by the v66 rebuild in database.dart.
          rawDb.execute('''
            CREATE TABLE dive_data_sources (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT NOT NULL REFERENCES dives(id) ON DELETE CASCADE,
              computer_id TEXT REFERENCES dive_computers(id) ON DELETE SET NULL,
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

          createV71MediaTableRaw(rawDb);
        },
      );
    }

    test(
      'fresh database has source_uuid column on dive_data_sources',
      () async {
        final db = AppDatabase(NativeDatabase.memory());
        addTearDown(db.close);

        final cols = await db
            .customSelect("PRAGMA table_info('dive_data_sources')")
            .get();
        final names = cols.map((c) => c.read<String>('name')).toSet();

        expect(
          names,
          contains('source_uuid'),
          reason: 'dive_data_sources must have source_uuid column',
        );
      },
    );

    test(
      'v69 -> v70 migration adds source_uuid column to dive_data_sources',
      () async {
        final nativeDb = setupDb();
        final db = AppDatabase(nativeDb);
        addTearDown(db.close);

        // Opening the database triggers the migration from v69 to v70.
        final cols = await db
            .customSelect("PRAGMA table_info('dive_data_sources')")
            .get();
        final names = cols.map((c) => c.read<String>('name')).toSet();

        expect(names, contains('source_uuid'));
      },
    );
  });
}
