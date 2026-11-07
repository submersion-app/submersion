import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
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

  /// Inserts a fully-formed imported track in one write.
  ///
  /// Unlike startTrack/appendBufferPoint/finalizeTrack, an import already has
  /// every point in hand, so it skips the local recording buffer entirely.
  Future<String> insertImportedTrack({
    required List<domain.GpsTrackPoint> points,
    required int startTimeMs,
    required int endTimeMs,
    required int tzOffsetMinutes,
    required String source,
    String? sourceRef,
    String? name,
    String? deviceName,
    int? trimStartTime,
    int? trimEndTime,
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
              endTime: Value(endTimeMs),
              tzOffsetMinutes: Value(tzOffsetMinutes),
              deviceName: Value(deviceName),
              pointCount: Value(points.length),
              points: Value(encodeTrackPoints(points)),
              trimStartTime: Value(trimStartTime),
              trimEndTime: Value(trimEndTime),
              // Always restate source explicitly. A Value.absent() here would
              // silently fall back to the 'phone' default and misattribute an
              // imported track.
              source: Value(source),
              sourceRef: Value(sourceRef),
              name: Value(name),
              createdAt: now,
              updatedAt: now,
            ),
          );
      // Without this the row's hlc stays NULL, and _exportGpsTracks filters
      // on `hlc > hlcSince` - SQL NULL is never greater than anything - so
      // the track would never ride an incremental changeset.
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
      return id;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to insert imported GPS track',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Test-only hook recording write operations in order.
  ///
  /// Exists so [splitTrack]'s ordering guarantee can be asserted directly:
  /// the final state looks identical whichever order the writes happened in,
  /// and the ordering is the entire safety property.
  @visibleForTesting
  void Function(String)? debugOnWrite;

  /// Sets non-destructive trim bounds. The points blob is untouched.
  ///
  /// Passing null for a bound leaves that end open; [clearTrim] removes both.
  /// Because the blob is never rewritten, trimming is free, fully reversible,
  /// a tiny sync payload, and incapable of losing a fix.
  Future<void> setTrimBounds(String id, {int? startMs, int? endMs}) async {
    try {
      final now = DateTime.now().millisecondsSinceEpoch;
      await (_db.update(_db.gpsTracks)..where((t) => t.id.equals(id))).write(
        GpsTracksCompanion(
          trimStartTime: Value(startMs),
          trimEndTime: Value(endMs),
          updatedAt: Value(now),
        ),
      );
      // updatedAt alone does not replicate: the export filters on hlc.
      await _syncRepository.markRecordPending(
        entityType: entityType,
        recordId: id,
        localUpdatedAt: now,
      );
      SyncEventBus.notifyLocalChange();
    } catch (e, stackTrace) {
      _log.error(
        'Failed to set trim bounds on GPS track $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Removes both trim bounds, restoring the full recording.
  Future<void> clearTrim(String id) => setTrimBounds(id);

  /// Splits [id] into two tracks at [atWallClockMs].
  ///
  /// The fix at the split point goes to the FIRST child. Returns the two new
  /// ids.
  ///
  /// ORDERING IS THE SAFETY PROPERTY: both children are written BEFORE the
  /// parent is tombstoned. A crash between those steps leaves two children
  /// and the parent - duplicates the user can delete. The reverse order
  /// would leave nothing.
  ///
  /// Splits the RAW blob, not [GpsTrack.effectivePoints], and carries the
  /// parent's trim bounds to both children. Trim is documented as reversible
  /// and incapable of losing a fix; building children from the trimmed view
  /// and then hard-deleting the parent would have quietly broken that promise
  /// the first time anyone split a trimmed track. Because the bounds are
  /// absolute timestamps, the same pair clips correctly on each child's own
  /// span, and Reset trim still recovers that child's hidden fixes.
  Future<(String, String)> splitTrack(String id, int atWallClockMs) async {
    final track = await getTrack(id, includePoints: true);
    if (track == null) {
      throw ArgumentError.value(id, 'id', 'No such track');
    }

    final atSeconds = atWallClockMs ~/ 1000;
    final points = track.points;
    final first = [
      for (final p in points)
        if (p.timestamp <= atSeconds) p,
    ];
    final second = [
      for (final p in points)
        if (p.timestamp > atSeconds) p,
    ];

    if (first.isEmpty || second.isEmpty) {
      throw ArgumentError.value(
        atWallClockMs,
        'atWallClockMs',
        'Split point must leave fixes on both sides',
      );
    }

    final baseName = track.name;
    final firstId = await insertImportedTrack(
      points: first,
      startTimeMs: first.first.timestamp * 1000,
      endTimeMs: first.last.timestamp * 1000,
      tzOffsetMinutes: track.tzOffsetMinutes,
      source: track.source,
      sourceRef: track.sourceRef,
      deviceName: track.deviceName,
      trimStartTime: track.trimStartTime,
      trimEndTime: track.trimEndTime,
      name: baseName == null ? null : '$baseName (1)',
    );
    debugOnWrite?.call('insert:$firstId');

    final secondId = await insertImportedTrack(
      points: second,
      startTimeMs: second.first.timestamp * 1000,
      endTimeMs: second.last.timestamp * 1000,
      tzOffsetMinutes: track.tzOffsetMinutes,
      source: track.source,
      sourceRef: track.sourceRef,
      deviceName: track.deviceName,
      trimStartTime: track.trimStartTime,
      trimEndTime: track.trimEndTime,
      name: baseName == null ? null : '$baseName (2)',
    );
    debugOnWrite?.call('insert:$secondId');

    // Only now that both children are durable.
    await deleteTrack(id);
    debugOnWrite?.call('delete:$id');

    return (firstId, secondId);
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
    final rows = await _bufferRows(trackId, timeOrder: true);
    return [for (final r in rows) _pointOf(r)];
  }

  /// Buffer rows for [trackId] with a rowId above [afterRowId]: in time
  /// order (ties in arrival order) for a full read, or in arrival order for
  /// an incremental one.
  Future<List<GpsTrackPointRow>> _bufferRows(
    String trackId, {
    int afterRowId = 0,
    required bool timeOrder,
  }) {
    final query = _db.select(_db.gpsTrackPointsLocal)
      ..where(
        (t) =>
            t.trackId.equals(trackId) & t.rowId.isBiggerThanValue(afterRowId),
      )
      ..orderBy([
        if (timeOrder) (t) => OrderingTerm.asc(t.timestamp),
        (t) => OrderingTerm.asc(t.rowId),
      ]);
    return query.get();
  }

  static domain.GpsTrackPoint _pointOf(GpsTrackPointRow r) =>
      domain.GpsTrackPoint(
        timestamp: r.timestamp,
        latitude: r.latitude,
        longitude: r.longitude,
        accuracy: r.accuracy,
      );

  /// What each recording's last checkpoint wrote, by track id.
  ///
  /// A cache, not state anything depends on: a repository without an entry
  /// (a fresh instance, or after a restart) rebuilds from the buffer.
  final Map<String, _CheckpointCursor> _checkpoints = {};

  /// Test-only hook reporting what each [checkpoint] call read, encoded and
  /// wrote, so the work per checkpoint can be asserted (issue #4255).
  @visibleForTesting
  void Function(({int rowsRead, int tuplesEncoded, bool wroteBlob}))?
  debugOnCheckpoint;

  /// Encodes the buffer into the synced blob without ending the session, so
  /// the synced copy is never more than one checkpoint interval stale.
  ///
  /// Reads and encodes only the fixes buffered since this repository's last
  /// checkpoint of the track, and writes nothing when there are none. Before
  /// issue #4255 every checkpoint read and re-encoded the whole track so
  /// far, so a long recording's total work grew with the square of its
  /// length. The gzip and the blob write still cover the whole track: the
  /// column is replaced whole, and both are cheap next to formatting the
  /// tuples.
  Future<void> checkpoint(String trackId) async {
    final cursor = _checkpoints[trackId];
    final rows = await _bufferRows(
      trackId,
      afterRowId: cursor?.lastRowId ?? 0,
      timeOrder: cursor == null,
    );
    if (rows.isEmpty) {
      debugOnCheckpoint?.call((
        rowsRead: 0,
        tuplesEncoded: 0,
        wroteBlob: false,
      ));
      return;
    }

    final List<GpsTrackPointRow> encodedRows;
    final List<String> tuples;
    var rowsRead = rows.length;
    if (cursor != null && _appendsInOrder(cursor.lastTimestamp, rows)) {
      encodedRows = rows;
      tuples = [
        ...cursor.tuples,
        for (final r in rows) encodeTrackPointTuple(_pointOf(r)),
      ];
    } else {
      // No cursor yet (rows is already the whole buffer in time order), or a
      // fix stamped before one already written: appending it would leave the
      // blob out of time order, so rebuild from the whole buffer.
      encodedRows = cursor == null
          ? rows
          : await _bufferRows(trackId, timeOrder: true);
      if (cursor != null) rowsRead += encodedRows.length;
      tuples = [
        for (final r in encodedRows) encodeTrackPointTuple(_pointOf(r)),
      ];
    }

    await _writeEncodedBlob(
      trackId,
      encodeTrackPointTuples(tuples),
      pointCount: tuples.length,
      endTimeMs: null,
    );
    // Only once the write landed: a cursor advanced past a failed write
    // would make the next checkpoint skip those fixes.
    // From the rows encoded, not the first read: a rebuild's second read can
    // include a fix appended in between, which must not be appended again.
    _checkpoints[trackId] = _CheckpointCursor(
      lastRowId: encodedRows.map((r) => r.rowId).reduce(_max),
      lastTimestamp: encodedRows.map((r) => r.timestamp).reduce(_max),
      tuples: tuples,
    );
    debugOnCheckpoint?.call((
      rowsRead: rowsRead,
      tuplesEncoded: encodedRows.length,
      wroteBlob: true,
    ));
  }

  static int _max(int a, int b) => a > b ? a : b;

  /// Whether [rows], in arrival order, never step back in time from
  /// [lastTimestamp] or from each other.
  static bool _appendsInOrder(int lastTimestamp, List<GpsTrackPointRow> rows) {
    var previous = lastTimestamp;
    for (final r in rows) {
      if (r.timestamp < previous) return false;
      previous = r.timestamp;
    }
    return true;
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
        _checkpoints.remove(trackId);
        return;
      }
      final end = endTimeMs ?? points.last.timestamp * 1000;
      await _writeBlob(trackId, points, endTimeMs: end);
      await (_db.delete(
        _db.gpsTrackPointsLocal,
      )..where((t) => t.trackId.equals(trackId))).go();
      _checkpoints.remove(trackId);
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
  }) => _writeEncodedBlob(
    trackId,
    encodeTrackPoints(points),
    pointCount: points.length,
    endTimeMs: endTimeMs,
  );

  Future<void> _writeEncodedBlob(
    String trackId,
    Uint8List blob, {
    required int pointCount,
    required int? endTimeMs,
  }) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    await (_db.update(_db.gpsTracks)..where((t) => t.id.equals(trackId))).write(
      GpsTracksCompanion(
        points: Value(blob),
        pointCount: Value(pointCount),
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
        final points = _decodePointsOrNull(row.id, row.points!);
        if (points == null || points.isEmpty) {
          // Left open and left alone. Recovery walks every orphan, so one
          // unreadable checkpoint must not abort the rest, and closing this
          // track would overwrite the only copy of the blob. A row whose
          // pointCount disagrees with an empty array lands here too: there
          // is no last point to close it at.
          continue;
        }
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

  /// Completed tracks, newest first. Without [includePoints] the points
  /// blob is left out of the query, so listing every recording (the Tracks
  /// list, the map, and the match sweep every import runs, issue #3704)
  /// reads no blob from disk.
  Future<List<domain.GpsTrack>> getCompletedTracks({
    bool includePoints = false,
  }) async {
    if (includePoints) {
      final rows =
          await (_db.select(_db.gpsTracks)
                ..where((t) => t.endTime.isNotNull())
                ..orderBy([(t) => OrderingTerm.desc(t.startTime)]))
              .get();
      return [for (final r in rows) _toDomain(r, includePoints: true)];
    }
    final table = _db.gpsTracks;
    String quoted(GeneratedColumn<Object> c) => '"${c.name}"';
    final columns = [
      for (final c in table.$columns)
        if (c != table.points) quoted(c),
    ].join(', ');
    final rows = await _db
        .customSelect(
          'SELECT $columns FROM ${table.actualTableName} '
          'WHERE ${quoted(table.endTime)} IS NOT NULL '
          'ORDER BY ${quoted(table.startTime)} DESC',
          readsFrom: {table},
        )
        .get();
    return [
      for (final r in rows) _toDomain(table.map(r.data), includePoints: false),
    ];
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
      _checkpoints.remove(id);
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

  /// Decodes a stored points blob, or null if it cannot be read.
  ///
  /// The blob is peer-supplied - gpsTracks syncs, and the points column
  /// rides as base64 - so a malformed one is a data condition, not a
  /// programming error. Every caller here degrades to a track with no points
  /// rather than propagating: the alternative is that one bad row from one
  /// device throws out of a repository read and takes the whole GPS log with
  /// it. This is NOT the derived geometry cache, so the failure is logged at
  /// error and the blob is left in place; nothing here silently repairs or
  /// discards the only copy of a track's points.
  List<domain.GpsTrackPoint>? _decodePointsOrNull(String id, Uint8List blob) {
    try {
      // Drift hands back a Uint8List already; copying it would double the
      // peak allocation on every read of a large track.
      return decodeTrackPoints(blob);
    } on TrackPointCodecException catch (e, stackTrace) {
      _log.error(
        'Unreadable points blob on GPS track $id; reporting it with no points',
        error: e,
        stackTrace: stackTrace,
      );
      return null;
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
          ? _decodePointsOrNull(row.id, row.points!) ?? const []
          : const [],
      source: row.source,
      sourceRef: row.sourceRef,
      name: row.name,
      trimStartTime: row.trimStartTime,
      trimEndTime: row.trimEndTime,
    );
  }
}

/// What a recording's last checkpoint wrote: the highest buffer rowId it
/// read, the latest fix time in the blob, and every tuple already encoded,
/// so the next checkpoint formats only fixes buffered since (issue #4255).
class _CheckpointCursor {
  const _CheckpointCursor({
    required this.lastRowId,
    required this.lastTimestamp,
    required this.tuples,
  });

  final int lastRowId;
  final int lastTimestamp;
  final List<String> tuples;
}
