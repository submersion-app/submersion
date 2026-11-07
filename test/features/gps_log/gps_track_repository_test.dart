import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';
import 'package:submersion/features/gps_log/domain/track_point_codec.dart';

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

    // Issue #4255: every checkpoint used to read, encode and rewrite the
    // whole track so far, so the work grew quadratically with duration.
    group('incremental checkpoint', () {
      GpsTrackPoint at(int t, {double lat = 1}) =>
          GpsTrackPoint(timestamp: t, latitude: lat, longitude: 2);

      late List<({int rowsRead, int tuplesEncoded, bool wroteBlob})> stats;

      setUp(() {
        stats = [];
        repo.debugOnCheckpoint = stats.add;
      });

      Future<String> startWith(List<GpsTrackPoint> points) async {
        final id = await repo.startTrack(
          startTimeMs: 1700000000000,
          tzOffsetMinutes: 0,
        );
        for (final p in points) {
          await repo.appendBufferPoint(id, p);
        }
        return id;
      }

      Future<GpsTrackRow> rowOf(String id) =>
          (db.select(db.gpsTracks)..where((t) => t.id.equals(id))).getSingle();

      test('later checkpoints read and encode only the new fixes', () async {
        final first = [at(1700000000), at(1700000010), at(1700000020)];
        final id = await startWith(first);
        await repo.checkpoint(id);

        final second = [at(1700000030, lat: 3), at(1700000040, lat: 4)];
        for (final p in second) {
          await repo.appendBufferPoint(id, p);
        }
        await repo.checkpoint(id);

        expect(stats.map((s) => (s.rowsRead, s.tuplesEncoded)), [
          (3, 3),
          (2, 2),
        ]);
        final row = await rowOf(id);
        expect(row.pointCount, 5);
        // Byte-identical to encoding the whole buffer at once.
        expect(row.points, encodeTrackPoints([...first, ...second]));
      });

      test('a checkpoint with no new fixes rewrites nothing', () async {
        final id = await startWith([at(1700000000)]);
        await repo.checkpoint(id);
        // Backdate the row so a rewrite would show.
        await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
          const GpsTracksCompanion(updatedAt: Value(1)),
        );

        await repo.checkpoint(id);

        expect(stats.last, (rowsRead: 0, tuplesEncoded: 0, wroteBlob: false));
        expect((await rowOf(id)).updatedAt, 1);
      });

      test('a failed blob write leaves the cursor, so the next checkpoint '
          'still writes those fixes', () async {
        final id = await startWith([at(1700000000)]);
        await repo.checkpoint(id);
        await repo.appendBufferPoint(id, at(1700000010));

        await db.customStatement(
          'CREATE TEMP TRIGGER fail_track_write BEFORE UPDATE ON gps_tracks '
          "BEGIN SELECT RAISE(ABORT, 'write failed'); END",
        );
        await expectLater(repo.checkpoint(id), throwsA(anything));
        await db.customStatement('DROP TRIGGER fail_track_write');

        await repo.checkpoint(id);

        expect(stats.last, (rowsRead: 1, tuplesEncoded: 1, wroteBlob: true));
        expect((await rowOf(id)).pointCount, 2);
      });

      test('a fix older than the last checkpointed one rebuilds the blob in '
          'time order', () async {
        final id = await startWith([at(1700000100), at(1700000200)]);
        await repo.checkpoint(id);
        await repo.appendBufferPoint(id, at(1700000150));

        await repo.checkpoint(id);

        final track = await repo.getTrack(id);
        expect(track!.points.map((p) => p.timestamp), [
          1700000100,
          1700000150,
          1700000200,
        ]);
        expect(stats.last.tuplesEncoded, 3);
      });

      test('a repository with no cached state checkpoints the whole buffer, '
          'then continues incrementally', () async {
        final id = await startWith([at(1700000000), at(1700000010)]);
        await repo.checkpoint(id);
        await repo.appendBufferPoint(id, at(1700000020));

        final fresh = GpsTrackRepository();
        final freshStats =
            <({int rowsRead, int tuplesEncoded, bool wroteBlob})>[];
        fresh.debugOnCheckpoint = freshStats.add;
        await fresh.checkpoint(id);
        await fresh.appendBufferPoint(id, at(1700000030));
        await fresh.checkpoint(id);

        expect(freshStats.map((s) => s.rowsRead), [3, 1]);
        expect((await rowOf(id)).pointCount, 4);
      });

      test(
        'finalize after incremental checkpoints writes the full track',
        () async {
          final id = await startWith([at(1700000000)]);
          await repo.checkpoint(id);
          await repo.appendBufferPoint(id, at(1700000010));
          await repo.checkpoint(id);
          await repo.appendBufferPoint(id, at(1700000020));

          await repo.finalizeTrack(id);

          final track = await repo.getTrack(id);
          expect(track!.points, hasLength(3));
          expect(track.endTime, 1700000020000);
        },
      );
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

  test('completed tracks listed without points carry every other field, '
      'newest first, and leave out a recording in progress', () async {
    Future<String> finished(int startMs) async {
      final id = await repo.startTrack(
        startTimeMs: startMs,
        tzOffsetMinutes: 60,
        deviceName: 'Phone',
      );
      await repo.appendBufferPoint(
        id,
        GpsTrackPoint(
          timestamp: startMs ~/ 1000 + 10,
          latitude: 1,
          longitude: 2,
        ),
      );
      await repo.finalizeTrack(id, endTimeMs: startMs + 60000);
      return id;
    }

    final older = await finished(1700000000000);
    final newer = await finished(1700100000000);
    await repo.setTrimBounds(newer, startMs: 1700100005000);
    await repo.startTrack(startTimeMs: 1700200000000, tzOffsetMinutes: 0);

    final full = await repo.getCompletedTracks(includePoints: true);
    final listed = await repo.getCompletedTracks();

    expect([for (final t in listed) t.id], [newer, older]);
    expect([for (final t in full) t.id], [newer, older]);
    for (var i = 0; i < listed.length; i++) {
      final a = listed[i];
      final b = full[i];
      expect(a.points, isEmpty);
      expect(b.points, isNotEmpty);
      expect(
        (
          a.startTime,
          a.endTime,
          a.tzOffsetMinutes,
          a.deviceName,
          a.pointCount,
          a.source,
          a.sourceRef,
          a.name,
          a.trimStartTime,
          a.trimEndTime,
        ),
        (
          b.startTime,
          b.endTime,
          b.tzOffsetMinutes,
          b.deviceName,
          b.pointCount,
          b.source,
          b.sourceRef,
          b.name,
          b.trimStartTime,
          b.trimEndTime,
        ),
      );
    }
    expect(listed.first.trimStartTime, 1700100005000);
    expect(listed.first.deviceName, 'Phone');
    expect(listed.first.pointCount, 1);
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
