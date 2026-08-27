import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late GpsTrackRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    await db.customStatement('PRAGMA foreign_keys = ON');
    repo = GpsTrackRepository();
  });

  tearDown(() async {
    await tearDownTestDatabase();
  });

  test('gps_tracks table accepts a row round-trip', () async {
    await db
        .into(db.gpsTracks)
        .insert(
          GpsTracksCompanion.insert(
            id: 'track-1',
            startTime: 1700000000000,
            createdAt: 1700000000000,
            updatedAt: 1700000000000,
          ),
        );
    final row = await (db.select(
      db.gpsTracks,
    )..where((t) => t.id.equals('track-1'))).getSingle();
    expect(row.endTime, isNull);
    expect(row.pointCount, 0);
  });

  test('gps_track_points_local accepts buffer rows', () async {
    await db
        .into(db.gpsTrackPointsLocal)
        .insert(
          GpsTrackPointsLocalCompanion.insert(
            trackId: 'track-1',
            timestamp: 1700000000,
            latitude: 20.5,
            longitude: -87.2,
          ),
        );
    final rows = await db.select(db.gpsTrackPointsLocal).get();
    expect(rows.single.latitude, 20.5);
  });

  group('GpsTrackRepository', () {
    test('startTrack inserts an active row', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: -300,
      );
      final track = await repo.getTrack(id);
      expect(track, isNotNull);
      expect(track!.endTime, isNull);
      expect(track.tzOffsetMinutes, -300);
    });

    test('checkpoint encodes buffer into blob without ending track', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000000, latitude: 1, longitude: 2),
      );
      await repo.checkpoint(id);
      final track = await repo.getTrack(id);
      expect(track!.endTime, isNull);
      expect(track.pointCount, 1);
      expect(track.points.single.latitude, 1);
      // Buffer survives a checkpoint (only finalize clears it).
      expect(await repo.getBufferPoints(id), hasLength(1));
    });

    test('finalizeTrack sets endTime, encodes points, clears buffer', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000100, latitude: 1, longitude: 2),
      );
      await repo.finalizeTrack(id, endTimeMs: 1700000200000);
      final track = await repo.getTrack(id);
      expect(track!.endTime, 1700000200000);
      expect(track.pointCount, 1);
      expect(await repo.getBufferPoints(id), isEmpty);
      expect(await repo.getCompletedTracks(), hasLength(1));
    });

    test(
      'finalizeTrack without endTimeMs uses last buffer point time',
      () async {
        final id = await repo.startTrack(
          startTimeMs: 1700000000000,
          tzOffsetMinutes: 0,
        );
        await repo.appendBufferPoint(
          id,
          const GpsTrackPoint(timestamp: 1700000500, latitude: 1, longitude: 2),
        );
        await repo.finalizeTrack(id);
        final track = await repo.getTrack(id);
        expect(track!.endTime, 1700000500000);
      },
    );

    test('recoverOrphanedTracks finalizes stale active tracks', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000300, latitude: 1, longitude: 2),
      );
      final recovered = await repo.recoverOrphanedTracks();
      expect(recovered, [id]);
      final track = await repo.getTrack(id);
      expect(track!.endTime, isNotNull);
    });

    test(
      'recoverOrphanedTracks closes stale checkpointed track with no buffer',
      () async {
        final id = await repo.startTrack(
          startTimeMs: 1700000000000,
          tzOffsetMinutes: 0,
        );
        await repo.appendBufferPoint(
          id,
          const GpsTrackPoint(timestamp: 1700000400, latitude: 3, longitude: 4),
        );
        await repo.checkpoint(id);
        // Simulate buffer loss (e.g. cleared by an interrupted finalize).
        await db.delete(db.gpsTrackPointsLocal).go();
        await _backdateUpdatedAt(db, id);
        final recovered = await repo.recoverOrphanedTracks();
        expect(recovered, [id]);
        final track = await repo.getTrack(id);
        expect(track!.endTime, 1700000400000);
        expect(track.points.single.latitude, 3);
      },
    );

    test('recoverOrphanedTracks leaves fresh buffer-less track open '
        '(may be recording on another device)', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000400, latitude: 3, longitude: 4),
      );
      await repo.checkpoint(id);
      await db.delete(db.gpsTrackPointsLocal).go();
      final recovered = await repo.recoverOrphanedTracks();
      expect(recovered, isEmpty);
      final track = await repo.getTrack(id);
      expect(track!.endTime, isNull);
    });

    test('recoverOrphanedTracks deletes stale empty orphans', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await _backdateUpdatedAt(db, id);
      await repo.recoverOrphanedTracks();
      expect(await repo.getTrack(id), isNull);
    });

    test('deleteTrack removes row and writes a tombstone', () async {
      final id = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        id,
        const GpsTrackPoint(timestamp: 1700000100, latitude: 1, longitude: 2),
      );
      await repo.finalizeTrack(id, endTimeMs: 1700000100000);
      await repo.deleteTrack(id);
      expect(await repo.getTrack(id), isNull);
      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.recordId.equals(id))).get();
      expect(tombstones, hasLength(1));
      expect(tombstones.single.entityType, 'gpsTracks');
    });
  });
}

/// Ages a track past the stale-orphan threshold so recovery will touch it.
Future<void> _backdateUpdatedAt(AppDatabase db, String id) async {
  final stale = DateTime.now()
      .subtract(GpsTrackRepository.staleOrphanThreshold * 2)
      .millisecondsSinceEpoch;
  await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
    GpsTracksCompanion(updatedAt: Value(stale)),
  );
}
