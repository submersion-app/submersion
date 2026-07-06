import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart'
    as domain;
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

/// Persistence for GPS surface tracks (discussion #289).
///
/// Recording writes high-frequency points to the local-only
/// gps_track_points_local buffer (no sync churn); checkpoint/finalize encode
/// the buffer into the synced gps_tracks blob. Deletes are tombstoned so
/// tracks stay deleted across devices.
class GpsTrackRepository {
  static const String entityType = 'gpsTracks';

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(GpsTrackRepository);

  Stream<void> watchTracksChanges() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.gpsTracks));

  Future<String> startTrack({
    required int startTimeMs,
    required int tzOffsetMinutes,
    String? deviceName,
  }) async {
    try {
      final id = _uuid.v4();
      final now = DateTime.now().millisecondsSinceEpoch;
      await _db
          .into(_db.gpsTracks)
          .insert(
            GpsTracksCompanion.insert(
              id: id,
              startTime: startTimeMs,
              tzOffsetMinutes: Value(tzOffsetMinutes),
              deviceName: Value(deviceName),
              createdAt: now,
              updatedAt: now,
            ),
          );
      return id;
    } catch (e, stackTrace) {
      _log.error('Failed to start GPS track', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> appendBufferPoint(
    String trackId,
    domain.GpsTrackPoint point,
  ) async {
    await _db
        .into(_db.gpsTrackPointsLocal)
        .insert(
          GpsTrackPointsLocalCompanion.insert(
            trackId: trackId,
            timestamp: point.timestamp,
            latitude: point.latitude,
            longitude: point.longitude,
            accuracy: Value(point.accuracy),
          ),
        );
  }

  Future<List<domain.GpsTrackPoint>> getBufferPoints(String trackId) async {
    final rows =
        await (_db.select(_db.gpsTrackPointsLocal)
              ..where((t) => t.trackId.equals(trackId))
              ..orderBy([(t) => OrderingTerm.asc(t.timestamp)]))
            .get();
    return [
      for (final r in rows)
        domain.GpsTrackPoint(
          timestamp: r.timestamp,
          latitude: r.latitude,
          longitude: r.longitude,
          accuracy: r.accuracy,
        ),
    ];
  }

  /// Encodes the buffer into the synced blob without ending the session, so
  /// the synced copy is never more than one checkpoint interval stale.
  Future<void> checkpoint(String trackId) async {
    final points = await getBufferPoints(trackId);
    if (points.isEmpty) return;
    await _writeBlob(trackId, points, endTimeMs: null);
  }

  /// Ends the session: encodes the buffer, stamps [endTimeMs] (defaults to
  /// the last recorded point's time) and clears the buffer. A session with
  /// no points is deleted outright: an empty track is useless.
  Future<void> finalizeTrack(String trackId, {int? endTimeMs}) async {
    try {
      final points = await getBufferPoints(trackId);
      if (points.isEmpty) {
        await (_db.delete(
          _db.gpsTracks,
        )..where((t) => t.id.equals(trackId))).go();
        return;
      }
      final end = endTimeMs ?? points.last.timestamp * 1000;
      await _writeBlob(trackId, points, endTimeMs: end);
      await (_db.delete(
        _db.gpsTrackPointsLocal,
      )..where((t) => t.trackId.equals(trackId))).go();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to finalize GPS track $trackId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _writeBlob(
    String trackId,
    List<domain.GpsTrackPoint> points, {
    required int? endTimeMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.gpsTracks)..where((t) => t.id.equals(trackId))).write(
      GpsTracksCompanion(
        points: Value(encodeTrackPoints(points)),
        pointCount: Value(points.length),
        endTime: endTimeMs != null ? Value(endTimeMs) : const Value.absent(),
        updatedAt: Value(now),
      ),
    );
    await _syncRepository.markRecordPending(
      entityType: entityType,
      recordId: trackId,
      localUpdatedAt: now,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// How stale a buffer-less open track must be before recovery closes it.
  /// Active sessions are checkpointed every few minutes, so anything not
  /// updated for this long is genuinely dead, not recording elsewhere.
  static const staleOrphanThreshold = Duration(hours: 24);

  /// Finalizes tracks left active by a crash or force-kill. Returns the ids
  /// of tracks recovered with points; empty local orphans are deleted.
  ///
  /// Must only run while no local recording session is active. A track with
  /// buffer rows crashed on this device and is finalized from the buffer.
  /// A buffer-less open track may be a session actively recording on another
  /// device (its checkpoints sync with endTime still null), so it is only
  /// closed once [staleOrphanThreshold] passes without an update.
  Future<List<String>> recoverOrphanedTracks() async {
    final orphans = await (_db.select(
      _db.gpsTracks,
    )..where((t) => t.endTime.isNull())).get();
    final recovered = <String>[];
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in orphans) {
      final buffered = await getBufferPoints(row.id);
      final isStale = now - row.updatedAt > staleOrphanThreshold.inMilliseconds;
      if (buffered.isNotEmpty) {
        await finalizeTrack(row.id);
        recovered.add(row.id);
      } else if (!isStale) {
        continue;
      } else if (row.points != null && row.pointCount > 0) {
        // A checkpoint survived but the buffer is gone: close the track at
        // its last checkpointed point.
        final points = decodeTrackPoints(Uint8List.fromList(row.points!));
        await _writeBlob(
          row.id,
          points,
          endTimeMs: points.last.timestamp * 1000,
        );
        recovered.add(row.id);
      } else {
        await (_db.delete(
          _db.gpsTracks,
        )..where((t) => t.id.equals(row.id))).go();
      }
    }
    return recovered;
  }

  Future<List<domain.GpsTrack>> getCompletedTracks({
    bool includePoints = false,
  }) async {
    final rows =
        await (_db.select(_db.gpsTracks)
              ..where((t) => t.endTime.isNotNull())
              ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
            .get();
    return [for (final r in rows) _toDomain(r, includePoints: includePoints)];
  }

  Future<domain.GpsTrack?> getTrack(
    String id, {
    bool includePoints = true,
  }) async {
    final row = await (_db.select(
      _db.gpsTracks,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : _toDomain(row, includePoints: includePoints);
  }

  Future<void> deleteTrack(String id) async {
    try {
      await (_db.delete(_db.gpsTracks)..where((t) => t.id.equals(id))).go();
      await (_db.delete(
        _db.gpsTrackPointsLocal,
      )..where((t) => t.trackId.equals(id))).go();
      await _syncRepository.logDeletion(entityType: entityType, recordId: id);
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to delete GPS track $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  domain.GpsTrack _toDomain(GpsTrackRow row, {required bool includePoints}) {
    return domain.GpsTrack(
      id: row.id,
      startTime: row.startTime,
      endTime: row.endTime,
      tzOffsetMinutes: row.tzOffsetMinutes,
      deviceName: row.deviceName,
      pointCount: row.pointCount,
      points: includePoints && row.points != null
          ? decodeTrackPoints(Uint8List.fromList(row.points!))
          : const [],
    );
  }
}
