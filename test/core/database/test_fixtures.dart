import 'package:sqlite3/sqlite3.dart';

/// Creates the v71-state `media` table on a raw SQLite [db].
///
/// Call this inside the `setup:` callback of [NativeDatabase.memory] for
/// older migration tests so the v72 migration's ALTER TABLE media statements
/// have a table to operate on. Real v71 production databases always have the
/// media table; only test fixtures that stub a minimal older-version schema
/// need this helper.
void createV71MediaTableRaw(Database db) {
  db.execute('''
    CREATE TABLE IF NOT EXISTS media (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT,
      site_id TEXT,
      file_path TEXT NOT NULL,
      file_type TEXT NOT NULL DEFAULT 'photo',
      latitude REAL,
      longitude REAL,
      taken_at INTEGER,
      caption TEXT,
      signer_id TEXT,
      signer_name TEXT,
      signature_type TEXT,
      image_data BLOB,
      platform_asset_id TEXT,
      original_filename TEXT,
      width INTEGER,
      height INTEGER,
      duration_seconds INTEGER,
      is_favorite INTEGER NOT NULL DEFAULT 0,
      thumbnail_generated_at INTEGER,
      last_verified_at INTEGER,
      is_orphaned INTEGER NOT NULL DEFAULT 0,
      created_at INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL DEFAULT 0
    )
  ''');
}

/// Creates the pre-v66 `dive_data_sources` table shape on a raw SQLite [db].
///
/// The v66 migration rebuilds `dive_data_sources` (create → copy → swap, to
/// change the `computer_id` foreign key action) and its guard only skips the
/// rebuild when the table does not exist at all; once it exists, the copy
/// step names every column the table carried immediately before v66, so a
/// migration test whose fixture starts below v66 needs this exact shape, not
/// a smaller stand-in, or the copy's `SELECT` fails on a missing column.
/// v182/v183 additionally need `dive_data_sources` to exist at all (any
/// shape) before they will create `dive_profile_series`, which is the other
/// reason a fixture below v66 cannot simply omit the table.
void createPreV66DiveDataSourcesTableRaw(Database db) {
  db.execute('''
    CREATE TABLE dive_data_sources (
      id TEXT NOT NULL PRIMARY KEY,
      dive_id TEXT NOT NULL,
      computer_id TEXT,
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
}
