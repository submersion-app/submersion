import 'dart:async';

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

  /// Track ids whose cached geometry has just been dropped.
  ///
  /// Static because eviction has more than one owner: SyncDataSerializer
  /// builds its own repository, and an instance stream would never reach the
  /// providers watching this one.
  static final _evictions = StreamController<String>.broadcast();

  /// How many times each track has been evicted this session. Static for the
  /// same reason as [_evictions]. A track with no entry is at generation 0.
  static final _generations = <String, int>{};

  LocalCacheDatabase get _db => LocalCacheDatabaseService.instance.database;

  /// Emits after [invalidate] drops [trackId]'s cached geometry, so a rendered
  /// polyline does not outlive the points it was built from.
  ///
  /// Scoped to one track, and silent on [write]: a table-wide tick would make
  /// every active preview reload each time any one of them cached its result
  /// (issue #3866). Works before the local cache database is initialised,
  /// since a track can be evicted while the cache is still an empty one.
  Stream<void> watchEvictions(String trackId) =>
      _evictions.stream.where((id) => id == trackId).map((_) {});

  /// The current generation of [trackId]'s geometry. Take it before reading
  /// the track's points, and hand it to [write] with what they simplified to.
  int generationOf(String trackId) => _generations[trackId] ?? 0;

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

  /// Caches [points] as [trackId]'s geometry at [lod].
  ///
  /// With a [generation] from [generationOf], the write is dropped if the
  /// track has been evicted since: those points may predate the trim, and the
  /// cache has no TTL, so a late write would pin the old line for good.
  Future<void> write(
    String trackId,
    TrackLod lod,
    List<GpsTrackPoint> points, {
    int? generation,
  }) async {
    if (generation != null && generation != generationOf(trackId)) return;
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
  ///
  /// The generation moves before the delete, so a simplification finishing
  /// while the delete runs cannot put the old line back. [watchEvictions]
  /// fires after it, so a listener that rereads the cache sees the rows gone.
  Future<void> invalidate(String trackId) async {
    _generations[trackId] = generationOf(trackId) + 1;
    final db = _dbOrNull;
    if (db != null) {
      await (db.delete(
        db.gpsTrackGeometryCache,
      )..where((t) => t.trackId.equals(trackId))).go();
    }
    _evictions.add(trackId);
  }
}
