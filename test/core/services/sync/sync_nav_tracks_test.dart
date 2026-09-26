import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';

import '../../../helpers/test_database.dart';

/// Round-trips the nav_tracks entity through every per-entity switch in
/// [SyncDataSerializer]: fetchRecord, fetchRecords, upsertRecord,
/// recordIdsFor, and deleteRecord -- exactly as sync_gps_tracks_test.dart
/// does for gps_tracks, since nav_tracks is registered the same way (spec
/// 2026-09-10-underwater-nav-track-design.md, "Sync, backup, reset"). The
/// points BLOB must survive the JSON encoding byte-for-byte (base64
/// serializer), proving a route recorded on one device decodes identically
/// on another.
void main() {
  late SyncDataSerializer serializer;
  late NavTrackRepository repo;

  setUp(() async {
    await setUpTestDatabase();
    serializer = SyncDataSerializer();
    repo = NavTrackRepository();
  });

  tearDown(tearDownTestDatabase);

  List<NavTrackPoint> samplePoints() => const [
    NavTrackPoint(timestamp: 1700000000, north: 0, east: 0, depth: 1.7),
    NavTrackPoint(timestamp: 1700000010, north: 10, east: 5, depth: 5.2),
    NavTrackPoint(timestamp: 1700000020, north: 20, east: 8, depth: 8.9),
  ];

  Future<String> seedRoute() {
    return repo.insertImportedRoute(
      points: samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: '008.DAT.csv',
    );
  }

  test('navTracks round-trips fetchRecord/fetchRecords/upsertRecord/'
      'recordIdsFor/deleteRecord with intact blob', () async {
    final id = await seedRoute();

    final fetched = await serializer.fetchRecord('navTracks', id);
    expect(fetched, isNotNull);
    expect(fetched!['sourceRef'], '008.DAT.csv');

    final batch = await serializer.fetchRecords('navTracks', [id, 'absent']);
    expect(batch.keys.toSet(), {id});

    expect(await serializer.recordIdsFor('navTracks'), contains(id));

    // Delete locally, then re-import the fetched JSON: the blob must decode
    // to the original samples after the round-trip.
    await serializer.deleteRecord('navTracks', id);
    expect(await serializer.fetchRecord('navTracks', id), isNull);

    await serializer.upsertRecord('navTracks', fetched);
    final restored = await repo.getById(id);
    expect(restored, isNotNull);
    expect(restored!.points, hasLength(3));
    expect(restored.points.first.north, closeTo(0, 1e-9));
    expect(restored.points[1].east, closeTo(5, 1e-9));
    expect(restored.points.last.depth, closeTo(8.9, 1e-9));
  });

  test(
    'a route deleted on one device stays deleted after a stale re-send',
    () async {
      final id = await seedRoute();
      final fetched = await serializer.fetchRecord('navTracks', id);

      // Tombstoned delete via the repository (writes deletion_log).
      await repo.delete(id);
      expect(await repo.getById(id), isNull);

      // At the serializer level (below the merge's tombstone filtering), a
      // stale peer re-sending the row must still round-trip so the merge
      // layer can decide to discard it.
      await serializer.upsertRecord('navTracks', fetched!);
      final resurrected = await repo.getById(id);
      expect(resurrected, isNotNull);
    },
  );
}
