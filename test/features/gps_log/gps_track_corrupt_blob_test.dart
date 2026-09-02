import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/gps_log/data/repositories/gps_track_repository.dart';
import 'package:submersion/features/gps_log/domain/entities/gps_track.dart';

import '../../helpers/test_database.dart';

/// Bytes that are not a gzip stream, standing in for a blob a peer wrote or
/// a round trip mangled. The authoritative reads see these verbatim: the
/// points column syncs as base64 and is inflated on read, never validated on
/// arrival.
final _corrupt = Uint8List.fromList(List<int>.filled(64, 0xAB));

Future<void> _corruptPoints(AppDatabase db, String id) async {
  await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
    GpsTracksCompanion(points: Value(_corrupt)),
  );
}

Future<void> _backdateUpdatedAt(AppDatabase db, String id) async {
  final stale = DateTime.now()
      .subtract(GpsTrackRepository.staleOrphanThreshold * 2)
      .millisecondsSinceEpoch;
  await (db.update(db.gpsTracks)..where((t) => t.id.equals(id))).write(
    GpsTracksCompanion(updatedAt: Value(stale)),
  );
}

/// Records a track with one point and ends it.
Future<String> _completedTrack(GpsTrackRepository repo, int timestamp) async {
  final id = await repo.startTrack(
    startTimeMs: timestamp * 1000,
    tzOffsetMinutes: 0,
  );
  await repo.appendBufferPoint(
    id,
    GpsTrackPoint(timestamp: timestamp, latitude: 1, longitude: 2),
  );
  await repo.finalizeTrack(id);
  return id;
}

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

  group('a corrupt points blob degrades one track, never the read', () {
    test(
      'getTrack returns the row with no points instead of throwing',
      () async {
        final id = await _completedTrack(repo, 1700000100);
        await _corruptPoints(db, id);

        final track = await repo.getTrack(id);
        expect(track, isNotNull);
        expect(track!.points, isEmpty);
        // The row's own metadata is untouched and still worth showing.
        expect(track.startTime, 1700000100000);
      },
    );

    test('getCompletedTracks still returns the healthy tracks', () async {
      final bad = await _completedTrack(repo, 1700000100);
      final good = await _completedTrack(repo, 1700000200);
      await _corruptPoints(db, bad);

      final tracks = await repo.getCompletedTracks(includePoints: true);
      expect(tracks.map((t) => t.id), containsAll([bad, good]));
      expect(tracks.firstWhere((t) => t.id == good).points, hasLength(1));
      expect(tracks.firstWhere((t) => t.id == bad).points, isEmpty);
    });

    test('the blob is left in place for a later read', () async {
      final id = await _completedTrack(repo, 1700000100);
      await _corruptPoints(db, id);

      await repo.getTrack(id);

      final row = await (db.select(
        db.gpsTracks,
      )..where((t) => t.id.equals(id))).getSingle();
      expect(row.points, _corrupt);
    });
  });

  group('recoverOrphanedTracks survives a corrupt checkpoint', () {
    test('skips the bad orphan and recovers the others', () async {
      final bad = await repo.startTrack(
        startTimeMs: 1700000000000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        bad,
        const GpsTrackPoint(timestamp: 1700000400, latitude: 3, longitude: 4),
      );
      await repo.checkpoint(bad);
      await db.delete(db.gpsTrackPointsLocal).go();
      await _corruptPoints(db, bad);
      await _backdateUpdatedAt(db, bad);

      final good = await repo.startTrack(
        startTimeMs: 1700000500000,
        tzOffsetMinutes: 0,
      );
      await repo.appendBufferPoint(
        good,
        const GpsTrackPoint(timestamp: 1700000600, latitude: 5, longitude: 6),
      );

      final recovered = await repo.recoverOrphanedTracks();

      expect(recovered, [good]);
      // Left open and left intact: recovery must not destroy a blob it
      // could not read, and must not delete a track that has points.
      final row = await (db.select(
        db.gpsTracks,
      )..where((t) => t.id.equals(bad))).getSingle();
      expect(row.endTime, isNull);
      expect(row.points, _corrupt);
    });
  });
}
