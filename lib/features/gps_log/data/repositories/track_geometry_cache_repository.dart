// Uint8List comes from drift's re-export; a dart:typed_data import here is
// flagged as unnecessary, and infos are fatal in CI.
import 'package:drift/drift.dart';

import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/local_cache_database_service.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

/// Level of detail for simplified track geometry.
enum TrackLod {
  /// Row thumbnails and unselected tracks on the overview map.
  thumbnail,

  /// Selected track on the overview map, detail page zoomed out.
  overview,

  /// Detail page at high zoom.
  detail;

  /// Douglas-Peucker tolerance in metres. Expressed in metres rather than
  /// pixels so simplification is independent of screen density.
  double get toleranceMeters => switch (this) {
    TrackLod.thumbnail => 50.0,
    TrackLod.overview => 10.0,
    TrackLod.detail => 2.0,
  };
}

/// Reads and writes simplified geometry in the local (unsynced) cache.
///
/// Constructed with no arguments and resolving the database through
/// [LocalCacheDatabaseService.instance], matching GpsTrackRepository's
/// convention of `AppDatabase get _db => DatabaseService.instance.database`.
class TrackGeometryCacheRepository {
  static final _log = LoggerService.forClass(TrackGeometryCacheRepository);

  LocalCacheDatabase get _db => LocalCacheDatabaseService.instance.database;

  /// Emits whenever cached geometry changes so map providers redraw after a
  /// trim or split invalidates a track's rows and the next render rewrites
  /// them.
  ///
  /// Not a write-once cache: [invalidate] deletes every LOD for a track and
  /// [write] re-inserts on conflict, so a rendered polyline can outlive the
  /// geometry it was built from.
  ///
  /// Emits nothing when the local cache database is not initialised, matching
  /// the "behave as an empty cache" contract the read/write methods use.
  Stream<void> watchGeometryChanges() {
    final LocalCacheDatabase db;
    try {
      db = _db;
    } on StateError {
      return const Stream.empty();
    }
    return db.tableUpdates(TableUpdateQuery.onTable(db.gpsTrackGeometryCache));
  }

  Future<void> _deleteRow(
    LocalCacheDatabase db,
    String trackId,
    TrackLod lod,
  ) async {
    await (db.delete(db.gpsTrackGeometryCache)
          ..where((t) => t.trackId.equals(trackId))
          ..where((t) => t.lodLevel.equals(lod.name)))
        .go();
  }

  /// The local cache database, or null before it has been initialised.
  ///
  /// This store is a pure derived cache: if it is not up yet, the correct
  /// behaviour is to behave as an empty cache, not to fail the caller. A
  /// track delete must never fail because a cache was unavailable.
  LocalCacheDatabase? get _dbOrNull {
    try {
      return _db;
    } on StateError {
      return null;
    }
  }

  /// Cached geometry, or null on a cache miss.
  ///
  /// An empty list is a real answer (the track has no drawable points) and
  /// is distinct from null (nothing cached yet).
  Future<List<GpsTrackPoint>?> read(String trackId, TrackLod lod) async {
    final db = _dbOrNull;
    if (db == null) return null;
    final row =
        await (db.select(db.gpsTrackGeometryCache)
              ..where((t) => t.trackId.equals(trackId))
              ..where((t) => t.lodLevel.equals(lod.name)))
            .getSingleOrNull();
    if (row == null) return null;
    if (row.status != 'ok') return const [];
    final blob = row.points;
    if (blob == null) return const [];
    try {
      // Drift hands back a Uint8List already; copying it would double the
      // peak allocation on every read of a large cached geometry.
      return decodeTrackPoints(blob);
    } catch (e, stackTrace) {
      // Everything here is re-derivable from gps_tracks, so a corrupt blob
      // must degrade to a cache miss, never to an error. Letting the throw
      // escape poisoned the track permanently: this store has no TTL and no
      // GC, so every subsequent read hit the same bad row and the map, the
      // thumbnail, and the detail page stayed broken for a track whose
      // underlying data was perfectly fine.
      _log.warning(
        'Discarding corrupt cached geometry for $trackId/${lod.name}',
        error: e,
        stackTrace: stackTrace,
      );
      await _deleteRow(db, trackId, lod);
      return null;
    }
  }

  Future<void> write(
    String trackId,
    TrackLod lod,
    List<GpsTrackPoint> points,
  ) async {
    final db = _dbOrNull;
    if (db == null) return;
    await db
        .into(db.gpsTrackGeometryCache)
        .insertOnConflictUpdate(
          GpsTrackGeometryCacheCompanion.insert(
            trackId: trackId,
            lodLevel: lod.name,
            status: points.isEmpty ? 'empty' : 'ok',
            // Milliseconds, matching every sibling table in this DB.
            createdAt: DateTime.now().millisecondsSinceEpoch,
            points: points.isEmpty
                ? const Value.absent()
                : Value(encodeTrackPoints(points)),
          ),
        );
  }

  /// Drops every cached LOD for [trackId]. Called after a trim or split
  /// changes which points the track represents.
  Future<void> invalidate(String trackId) async {
    final db = _dbOrNull;
    if (db == null) return;
    await (db.delete(
      db.gpsTrackGeometryCache,
    )..where((t) => t.trackId.equals(trackId))).go();
  }
}
