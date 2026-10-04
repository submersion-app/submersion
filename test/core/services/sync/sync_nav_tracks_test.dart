import 'package:drift/drift.dart' show TableUpdateQuery;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
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
  late AppDatabase db;

  setUp(() async {
    db = await setUpTestDatabase();
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

  test('a route\'s owner (v252 diver_id) travels with it', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'me', 1, 1)",
    );
    final id = await repo.insertImportedRoute(
      points: samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: '008.DAT.csv',
      diverId: 'me',
    );

    final fetched = await serializer.fetchRecord('navTracks', id);
    expect(fetched!['diverId'], 'me');

    await serializer.deleteRecord('navTracks', id);
    await serializer.upsertRecord('navTracks', fetched);

    final row = await db
        .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$id'")
        .getSingle();
    expect(row.read<String?>('diver_id'), 'me');
  });

  test('a linked route from a peer that predates its owner column takes its '
      'dive\'s diver once the apply is repaired', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'me', 1, 1)",
    );
    await db.customStatement(
      "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
      "updated_at) VALUES ('my-dive', 'me', 1700000000000, 1, 1)",
    );
    final id = await seedRoute();
    final fetched = (await serializer.fetchRecord('navTracks', id))!;
    await serializer.deleteRecord('navTracks', id);
    // What a v240-v251 peer sends after linking it: no diverId at all.
    final fromOlderPeer = {...fetched, 'diveId': 'my-dive'}..remove('diverId');

    await serializer.upsertRecord('navTracks', fromOlderPeer);
    await serializer.repairDanglingForeignKeys();

    final row = await db
        .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$id'")
        .getSingle();
    expect(row.read<String?>('diver_id'), 'me');
  });

  test('an adopted or restored row from a peer that predates the owner '
      'column keeps an unlinked route\'s local owner', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'me', 1, 1)",
    );
    final id = await repo.insertImportedRoute(
      points: samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: '008.DAT.csv',
      diverId: 'me',
    );
    final fetched = (await serializer.fetchRecord('navTracks', id))!;
    // The adopt and restore paths hand a peer's row straight to
    // upsertRecord, with no merge overlay; a v240-v251 peer omits diverId.
    final fromOlderPeer = {...fetched, 'name': 'Renamed'}..remove('diverId');

    await serializer.upsertRecord('navTracks', fromOlderPeer);
    await serializer.repairDanglingForeignKeys();

    final row = await db
        .customSelect("SELECT diver_id, name FROM nav_tracks WHERE id = '$id'")
        .getSingle();
    expect(row.read<String?>('name'), 'Renamed');
    expect(row.read<String?>('diver_id'), 'me');
  });

  test('the repair leaves an unlinked route\'s owner alone', () async {
    await db.customStatement(
      "INSERT INTO divers (id, name, created_at, updated_at) "
      "VALUES ('me', 'me', 1, 1)",
    );
    final id = await repo.insertImportedRoute(
      points: samplePoints(),
      source: NavTrackSource.seacraftEnc,
      sourceRef: '008.DAT.csv',
      diverId: 'me',
    );

    await serializer.repairDanglingForeignKeys();

    final row = await db
        .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$id'")
        .getSingle();
    expect(row.read<String?>('diver_id'), 'me');
  });

  group('re-owning a linked route after a synced dive changes diver', () {
    late String routeId;

    setUp(() async {
      for (final id in ['me', 'buddy']) {
        await db.customStatement(
          "INSERT INTO divers (id, name, created_at, updated_at) "
          "VALUES ('$id', '$id', 1, 1)",
        );
      }
      await db.customStatement(
        "INSERT INTO dives (id, diver_id, dive_date_time, created_at, "
        "updated_at) VALUES ('d', 'me', 1700000000000, 1, 1)",
      );
      routeId = await repo.insertImportedRoute(
        points: samplePoints(),
        source: NavTrackSource.seacraftEnc,
        sourceRef: '008.DAT.csv',
        diverId: 'me',
      );
      await repo.link(routeId, 'd', linkMode: NavTrackLinkMode.manual);
    });

    /// How many nav_tracks change notifications [body] sends, once its
    /// transaction has committed and Drift has delivered them.
    Future<int> routeNotificationsDuring(Future<void> Function() body) async {
      // Let the seeding writes' own notifications drain first.
      await pumpEventQueue();
      var count = 0;
      final sub = db
          .tableUpdates(TableUpdateQuery.onTable(db.navTracks))
          .listen((_) => count++);
      addTearDown(sub.cancel);
      await body();
      await pumpEventQueue();
      return count;
    }

    test('tells route watchers, so the routes list drops it (#2851)', () async {
      final dive = (await serializer.fetchRecord('dives', 'd'))!;

      final notifications = await routeNotificationsDuring(
        () => serializer.applyInDeferredFkTransaction(() async {
          // The dive alone arrives; its route is not in the payload.
          await serializer.upsertRecord('dives', {...dive, 'diverId': 'buddy'});
          await serializer.repairDanglingForeignKeys();
        }),
      );

      final row = await db
          .customSelect("SELECT diver_id FROM nav_tracks WHERE id = '$routeId'")
          .getSingle();
      expect(row.read<String?>('diver_id'), 'buddy');
      expect(notifications, greaterThan(0));
    });

    test('stays quiet when every linked route already has its owner', () async {
      final notifications = await routeNotificationsDuring(
        serializer.alignLinkedRouteOwners,
      );

      expect(notifications, 0);
    });
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
