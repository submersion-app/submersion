import 'dart:convert';

import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/bathymetry/domain/bathymetry_grid.dart';

/// A cached 'ok' tile plus the freshness bookkeeping the periodic staleness
/// check needs: the STAC version token it was downloaded under, and when
/// that token was last confirmed current.
class SwissBathyTileCacheEntry {
  final BathymetryGrid grid;

  /// The STAC item `datetime` (or fallback) this tile was downloaded under.
  /// Null for tiles cached before this field existed (v14) — treated as
  /// "unknown version", so the first freshness check always touches it
  /// rather than comparing against nothing.
  final String? sourceDatetime;

  /// When [sourceDatetime] was last confirmed current. Null means "never
  /// checked" (including rows written before this field existed).
  final DateTime? checkedAt;

  /// The href of the STAC asset [sourceDatetime] was read from — lets a
  /// freshness check match back to the exact previously-covering candidate.
  /// Null for tiles cached before this field existed (v15 and earlier).
  final String? sourceHref;

  /// The lake reference level this entry's [grid] depths were computed
  /// against — see [LocalCacheDatabase]'s `SwissBathyTileCache.
  /// referenceLevelMeters` doc for why [read] never actually returns an
  /// entry whose stored level does not match what the caller expects: a
  /// mismatch (including this being null, from before the field existed)
  /// deletes the row and returns null instead, so this field is really
  /// only informative for a caller not passing `expectedReferenceLevelMeters`.
  final double? referenceLevelMeters;

  const SwissBathyTileCacheEntry({
    required this.grid,
    this.sourceDatetime,
    this.checkedAt,
    this.sourceHref,
    this.referenceLevelMeters,
  });
}

/// Cache-first access to one swissBATHY3D tile's parsed, depth-converted
/// grid, keyed by the LV95 1-km tile index (e.g. "2600_1200"). This is the
/// layer that guarantees a tile is downloaded and parsed only once, per the
/// task's OGD fair-use requirement — independent of, and finer-grained
/// than, the outer [BathymetryCache]'s 0.02 degree quantized cells.
class SwissBathyTileCacheRepository {
  final LocalCacheDatabase _db;

  const SwissBathyTileCacheRepository(this._db);

  /// The cached entry for [tileKey], or null when uncached, when the tile
  /// is a cached negative ('empty'), OR when [expectedReferenceLevelMeters]
  /// is given and does not match the level the row was actually cached
  /// under (see `SwissBathyTileCache.referenceLevelMeters`'s doc) — the row
  /// is deleted in that case too, exactly like corruption, so the caller
  /// re-fetches and gets a correctly depth-converted grid instead of
  /// silently serving stale, wrongly-converted depths forever. Passing null
  /// (the default) skips this check entirely. Use [hasCachedAnswer] to tell
  /// "never looked up" apart from any of these deleted-and-null outcomes.
  Future<SwissBathyTileCacheEntry?> read(
    String tileKey, {
    double? expectedReferenceLevelMeters,
  }) async {
    final row = await (_db.select(
      _db.swissBathyTileCache,
    )..where((t) => t.tileKey.equals(tileKey))).getSingleOrNull();
    if (row == null) return null;
    if (expectedReferenceLevelMeters != null &&
        row.referenceLevelMeters != expectedReferenceLevelMeters) {
      // Checked before the status guard below, and so applies to a cached
      // 'empty' row exactly like an 'ok' one: a lake bbox correction can
      // turn a tile that was genuinely dry land under the OLD lake
      // assignment into real, covered water under the new one, so a stale
      // negative is exactly as unreliable as a stale positive would be.
      // Without this, [hasCachedAnswer] would keep reporting the tile as
      // definitively resolved forever, and the caller would never retry it
      // (Copilot review). A stored null (pre-v17 row) counts as a mismatch
      // too: there is no way to tell whether its cached answer is still
      // correct without this field, so it gets the same one-time
      // re-resolution every other pre-existing-row migration in this table
      // already falls back to.
      await (_db.delete(
        _db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals(tileKey))).go();
      return null;
    }
    if (row.status != 'ok') return null;
    final json = row.gridJson;
    if (json == null) {
      // Inconsistent row ('ok' but no grid): delete so callers retry instead
      // of treating it as a cached negative.
      await (_db.delete(
        _db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals(tileKey))).go();
      return null;
    }
    try {
      final grid = BathymetryGrid.fromJson(
        jsonDecode(json) as Map<String, dynamic>,
      );
      return SwissBathyTileCacheEntry(
        grid: grid,
        sourceDatetime: row.sourceDatetime,
        checkedAt: row.checkedAt == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(row.checkedAt!),
        sourceHref: row.sourceHref,
        referenceLevelMeters: row.referenceLevelMeters,
      );
    } catch (_) {
      // Corrupt row: delete so callers retry instead of treating it as a cached negative.
      await (_db.delete(
        _db.swissBathyTileCache,
      )..where((t) => t.tileKey.equals(tileKey))).go();
      return null;
    }
  }

  /// Whether a definitive answer ('ok' or 'empty') is already cached for
  /// [tileKey]. False means "never resolved" or "a transient failure left
  /// no row" — both should retry.
  Future<bool> hasCachedAnswer(String tileKey) async {
    final row = await (_db.select(
      _db.swissBathyTileCache,
    )..where((t) => t.tileKey.equals(tileKey))).getSingleOrNull();
    return row != null;
  }

  /// Every cached tile key, 'ok' AND 'empty' alike. Used by the manual
  /// "reload map data" action, which revalidates every cached tile
  /// immediately instead of waiting for each one's individual
  /// [SwissBathy3dSource.staleCheckInterval] to elapse. Negative rows are
  /// included, not just positive ones: a negative cached under a
  /// reference level that no longer matches (a lake bbox/level
  /// correction) is exactly as stale as a positive one would be, and
  /// [read]'s mismatch check only ever runs for a tile key this sweep
  /// actually visits.
  Future<List<String>> allTileKeys() async {
    final rows = await _db.select(_db.swissBathyTileCache).get();
    return [for (final row in rows) row.tileKey];
  }

  /// Deletes [tileKey] if its stored [referenceLevelMeters] does not match
  /// any of [currentLevels], a no-op (never deletes) when it matches one
  /// of them or the tile is uncached. For a sweep visiting a tile whose
  /// OWN center no longer resolves to any registered lake -- so there is
  /// no single current lake to pass to [read]'s normal
  /// expectedReferenceLevelMeters check -- but which may still hold a
  /// valid row cached under a lake the fetch that found it fell back to
  /// (see [SwissBathy3dSource.fetch]'s tileLake fallback). Matching
  /// against every currently registered level, not just one, is looser
  /// than [read]'s per-lookup check, but still correctly deletes a row
  /// whose level belongs to no lake in the CURRENT table at all -- the
  /// actual staleness signal a lake removal or a documented level
  /// correction leaves behind.
  Future<bool> deleteIfLevelUnknown(
    String tileKey,
    Iterable<double> currentLevels,
  ) async {
    final row = await (_db.select(
      _db.swissBathyTileCache,
    )..where((t) => t.tileKey.equals(tileKey))).getSingleOrNull();
    if (row == null) return false;
    if (row.referenceLevelMeters != null &&
        currentLevels.contains(row.referenceLevelMeters)) {
      return false;
    }
    await (_db.delete(
      _db.swissBathyTileCache,
    )..where((t) => t.tileKey.equals(tileKey))).go();
    return true;
  }

  Future<void> writeOk(
    String tileKey,
    BathymetryGrid grid, {
    String? sourceDatetime,
    String? sourceHref,
    required double referenceLevelMeters,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db
        .into(_db.swissBathyTileCache)
        .insertOnConflictUpdate(
          SwissBathyTileCacheCompanion.insert(
            tileKey: tileKey,
            status: 'ok',
            gridJson: Value(jsonEncode(grid.toJson())),
            fetchedAt: now,
            sourceDatetime: Value(sourceDatetime),
            checkedAt: Value(now),
            sourceHref: Value(sourceHref),
            referenceLevelMeters: Value(referenceLevelMeters),
          ),
        );
  }

  Future<void> writeEmpty(
    String tileKey, {
    required double referenceLevelMeters,
  }) async {
    await _db
        .into(_db.swissBathyTileCache)
        .insertOnConflictUpdate(
          SwissBathyTileCacheCompanion.insert(
            tileKey: tileKey,
            status: 'empty',
            fetchedAt: DateTime.now().millisecondsSinceEpoch,
            referenceLevelMeters: Value(referenceLevelMeters),
          ),
        );
  }

  /// Records that [tileKey]'s freshness was just confirmed, without
  /// touching its grid: the periodic check found no version change (or
  /// could not tell), so only the checked-at stamp advances, pushing the
  /// next check [SwissBathy3dSource.staleCheckInterval] into the future.
  /// A no-op when [tileKey] has no 'ok' row (nothing to touch).
  Future<void> touch(String tileKey, {String? sourceDatetime}) async {
    await (_db.update(
      _db.swissBathyTileCache,
    )..where((t) => t.tileKey.equals(tileKey) & t.status.equals('ok'))).write(
      SwissBathyTileCacheCompanion(
        checkedAt: Value(DateTime.now().millisecondsSinceEpoch),
        sourceDatetime: sourceDatetime == null
            ? const Value.absent()
            : Value(sourceDatetime),
      ),
    );
  }
}
