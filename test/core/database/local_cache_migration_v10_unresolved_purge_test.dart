import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';

/// v10 drops poisoned negative resolutions.
///
/// The gallery search window used to be built by copying a UTC DateTime's
/// calendar fields into a LOCAL DateTime, shifting it by the whole UTC offset,
/// so the raw-instant reading of `taken_at` was never actually queried. Rows
/// matching only on that reading were recorded `unresolved` and then locked
/// behind a 24h/3d/7d backoff -- meaning the matching fix would not take
/// effect for up to a week without this purge.
LocalCacheDatabase _storedV9({required List<List<Object?>> assetCacheRows}) {
  return LocalCacheDatabase(
    NativeDatabase.memory(
      setup: (raw) {
        // Minimal v9 shape: the v10 step only deletes rows, so the pre-existing
        // tables need to exist rather than be column-perfect.
        raw
          ..execute(
            'CREATE TABLE local_asset_cache '
            '(media_id TEXT PRIMARY KEY, local_asset_id TEXT, '
            'resolved_at INTEGER, resolution_method TEXT, '
            'attempt_count INTEGER)',
          )
          ..execute(
            'CREATE TABLE media_transfer_queue '
            '(id INTEGER PRIMARY KEY AUTOINCREMENT, media_id TEXT)',
          )
          ..execute(
            'CREATE TABLE media_cache_entries '
            '(content_hash TEXT, kind TEXT, PRIMARY KEY (content_hash, kind))',
          );
        for (final row in assetCacheRows) {
          raw.execute(
            'INSERT INTO local_asset_cache '
            '(media_id, local_asset_id, resolved_at, resolution_method, '
            'attempt_count) VALUES (?, ?, ?, ?, ?)',
            row,
          );
        }
        raw.execute('PRAGMA user_version = 9');
      },
    ),
  );
}

void main() {
  test('upgrading from v9 purges unresolved entries', () async {
    final db = _storedV9(
      assetCacheRows: [
        ['m-1', null, 1766846556000, 'unresolved', 2],
        ['m-2', null, 1766846557000, 'unresolved', 0],
      ],
    );
    addTearDown(db.close);

    final rows = await db.select(db.localAssetCache).get();

    expect(rows, isEmpty);
  });

  test('upgrading from v9 keeps resolved mappings', () async {
    // Resolved mappings are correct and expensive to re-derive (a full gallery
    // scan each), so the purge must not touch them.
    final db = _storedV9(
      assetCacheRows: [
        ['m-1', 'ASSET-1/L0/001', 1766846556000, 'original_id', 0],
        [
          'm-2',
          'ASSET-2/L0/001',
          1766846557000,
          'exact_timestamp_dimensions',
          0,
        ],
        ['m-3', null, 1766846558000, 'unresolved', 1],
      ],
    );
    addTearDown(db.close);

    final rows = await db.select(db.localAssetCache).get();

    expect(rows.map((r) => r.mediaId), unorderedEquals(['m-1', 'm-2']));
    expect(rows.every((r) => r.localAssetId != null), isTrue);
  });

  test('a fresh database is at or past v10', () async {
    final db = LocalCacheDatabase(NativeDatabase.memory());
    addTearDown(db.close);

    expect(db.schemaVersion, greaterThanOrEqualTo(10));
  });
}
