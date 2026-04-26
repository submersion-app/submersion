import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

void main() {
  test('migration to v72 adds new media columns', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 71');

          // v71 schema: media table before v72 migration.
          // Only includes columns that exist before the migration.
          rawDb.execute('''
            CREATE TABLE media (
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
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    addTearDown(db.close);

    final cols = await db.customSelect("PRAGMA table_info('media')").get();
    final names = cols.map((r) => r.read<String>('name')).toSet();

    expect(
      names,
      containsAll([
        'source_type',
        'local_path',
        'bookmark_ref',
        'url',
        'subscription_id',
        'entry_key',
        'connector_account_id',
        'remote_asset_id',
        'origin_device_id',
      ]),
    );
  });

  test('migration to v72 creates new tables', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 71');

          // v71 schema: minimal schema with media table to test CREATE TABLE
          // statements during migration.
          rawDb.execute('''
            CREATE TABLE IF NOT EXISTS divers (
              id TEXT NOT NULL PRIMARY KEY,
              name TEXT NOT NULL,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
          rawDb.execute('''
            CREATE TABLE media (
              id TEXT NOT NULL PRIMARY KEY,
              dive_id TEXT,
              file_path TEXT NOT NULL,
              file_type TEXT NOT NULL DEFAULT 'photo',
              platform_asset_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');
        },
      ),
    );
    addTearDown(db.close);

    final tables = await db
        .customSelect("SELECT name FROM sqlite_master WHERE type='table'")
        .get();
    final names = tables.map((r) => r.read<String>('name')).toSet();

    expect(
      names,
      containsAll([
        'media_subscriptions',
        'media_subscription_state',
        'connector_accounts',
        'network_credential_hosts',
        'media_fetch_diagnostics',
      ]),
    );
  });

  test('migration to v72 backfills source_type from existing rows', () async {
    final db = AppDatabase(
      NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA foreign_keys = ON');
          rawDb.execute('PRAGMA user_version = 71');

          // v71 schema: media table before v72 migration.
          rawDb.execute('''
            CREATE TABLE media (
              id TEXT NOT NULL PRIMARY KEY,
              file_path TEXT NOT NULL,
              file_type TEXT NOT NULL DEFAULT 'photo',
              platform_asset_id TEXT,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL
            )
          ''');

          // Seed pre-migration rows.
          rawDb.execute('''
            INSERT INTO media (id, file_path, file_type, platform_asset_id, created_at, updated_at)
            VALUES ('a', '', 'photo', 'PHASSET_1', 0, 0)
          ''');
          rawDb.execute('''
            INSERT INTO media (id, file_path, file_type, platform_asset_id, created_at, updated_at)
            VALUES ('b', '/Users/me/sig.png', 'instructor_signature', NULL, 0, 0)
          ''');
          rawDb.execute('''
            INSERT INTO media (id, file_path, file_type, platform_asset_id, created_at, updated_at)
            VALUES ('c', '/Users/me/photo.jpg', 'photo', NULL, 0, 0)
          ''');
        },
      ),
    );
    addTearDown(db.close);

    final rows = await db
        .customSelect('SELECT id, source_type, local_path FROM media')
        .get();
    final byId = {for (final r in rows) r.read<String>('id'): r};

    expect(byId['a']!.read<String>('source_type'), 'platformGallery');
    expect(byId['b']!.read<String>('source_type'), 'signature');
    expect(byId['c']!.read<String>('source_type'), 'localFile');
    expect(byId['c']!.read<String?>('local_path'), '/Users/me/photo.jpg');

    await db.close();
  });
}
