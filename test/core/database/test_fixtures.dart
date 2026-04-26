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
