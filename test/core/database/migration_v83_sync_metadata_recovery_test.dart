import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';

/// Migration 83 is the comprehensive recovery for databases stranded by the
/// schema-version collisions across the parallel sync branches. The v77 HLC /
/// surface-interval-index collision was only the first; the abandoned
/// encrypted-sync and iCloud-diagnostic lineages also reused v78-v81 for
/// unrelated migrations. A database that reached user_version >= 78 via one of
/// those branches skipped the canonical sync_metadata ALTERs (instance_token at
/// v78, last_accepted_epoch_id at v80, last_sync_provider at v81). The v82 block
/// only re-added hlc, so those sync_metadata columns stayed missing once the
/// database sat at the current version and stopped running onUpgrade -- every
/// identity write then failed with "no such column: instance_token".
///
/// These tests reproduce the observed stranded states (captured from real
/// device backups) and assert the v83 block re-asserts every missing column.
void main() {
  // The full set of post-v76 sync_metadata columns the recovery must guarantee.
  const recoveredColumns = [
    'hlc',
    'instance_token',
    'last_accepted_epoch_id',
    'last_sync_provider',
  ];

  Future<Set<String>> syncMetadataColumns(AppDatabase db) async {
    final cols = await db
        .customSelect("PRAGMA table_info('sync_metadata')")
        .get();
    return cols.map((c) => c.read<String>('name')).toSet();
  }

  test(
    'v82 stranded DB (missing only instance_token) recovers the column',
    () async {
      // Exactly the state captured from a real stranded backup: user_version is
      // already 82 (so the v82 block never re-runs) and sync_metadata carries
      // hlc + epoch + provider but NOT instance_token.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 82');
          rawDb.execute('''
            CREATE TABLE sync_metadata (
              id TEXT NOT NULL PRIMARY KEY,
              last_sync_timestamp INTEGER,
              device_id TEXT NOT NULL,
              sync_provider TEXT,
              remote_file_id TEXT,
              sync_version INTEGER NOT NULL DEFAULT 1,
              created_at INTEGER NOT NULL,
              updated_at INTEGER NOT NULL,
              last_accepted_epoch_id TEXT,
              last_sync_provider TEXT,
              hlc TEXT
            )
          ''');
        },
      );
      final db = AppDatabase(native);
      addTearDown(db.close);

      final cols = await syncMetadataColumns(db);
      expect(
        cols.contains('instance_token'),
        isTrue,
        reason: 'v83 recovery must add the missing instance_token column',
      );
    },
  );

  test(
    'v81 stranded DB recovers instance_token, epoch, and provider together',
    () async {
      // A database stranded at user_version = 81 with none of the post-v76
      // sync_metadata columns: the v82 block only adds hlc, leaving the three
      // sync_metadata text columns missing.
      final native = NativeDatabase.memory(
        setup: (rawDb) {
          rawDb.execute('PRAGMA user_version = 81');
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

      final cols = await syncMetadataColumns(db);
      for (final column in recoveredColumns) {
        expect(
          cols.contains(column),
          isTrue,
          reason: 'v83 recovery must ensure $column exists',
        );
      }
    },
  );

  test('v83 recovery preserves existing sync_metadata rows', () async {
    final native = NativeDatabase.memory(
      setup: (rawDb) {
        rawDb.execute('PRAGMA user_version = 82');
        rawDb.execute('''
          CREATE TABLE sync_metadata (
            id TEXT NOT NULL PRIMARY KEY,
            device_id TEXT NOT NULL,
            last_accepted_epoch_id TEXT,
            last_sync_provider TEXT,
            hlc TEXT
          )
        ''');
        rawDb.execute(
          "INSERT INTO sync_metadata (id, device_id) "
          "VALUES ('global', 'dev-keep')",
        );
      },
    );
    final db = AppDatabase(native);
    addTearDown(db.close);

    final row = await db
        .customSelect(
          "SELECT device_id, instance_token FROM sync_metadata "
          "WHERE id = 'global'",
        )
        .getSingle();
    expect(row.read<String>('device_id'), 'dev-keep');
    expect(
      row.read<String?>('instance_token'),
      isNull,
      reason:
          'recovered rows start with a null instance token (first-run seed)',
    );
  });

  test('healthy current-schema DB is left unchanged by the recovery', () async {
    // A freshly created database at the current schema already has every column
    // and must survive the recovery untouched (PRAGMA-guarded ALTERs no-op).
    final db = AppDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    final cols = await syncMetadataColumns(db);
    for (final column in recoveredColumns) {
      expect(cols.contains(column), isTrue, reason: '$column should exist');
    }
  });
}
