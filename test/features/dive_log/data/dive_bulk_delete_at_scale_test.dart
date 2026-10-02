import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive, DivePlan;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/series_id_chunks.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/nav_track/data/repositories/nav_track_repository.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track.dart';
import 'package:submersion/features/nav_track/domain/entities/nav_track_point.dart';
import 'package:submersion/features/planner/data/repositories/dive_plan_repository.dart';
import 'package:submersion/features/planner/domain/entities/dive_plan.dart';

import '../../../helpers/test_database.dart';

/// The bundled SQLite binds at most 32766 variables per statement, so a bulk
/// delete that puts every selected id into one `IN (...)` fails once "select
/// all" on a large logbook passes that many dives (issue #1953). Every step
/// of the delete has to chunk: the media partition and unlink, the plan
/// links, the route lookup, the dive rows and the tombstones.
void main() {
  // One past the bound-variable ceiling.
  const count = 33000;
  const epoch = 1000;

  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaRepository mediaRepository;
  late DiveRepository diveRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    mediaRepository = MediaRepository();
    diveRepository = DiveRepository(
      mediaRepository: mediaRepository,
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: mediaRepository,
        queue: () => MediaTransferQueueRepository(database: cacheDb),
      ),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  List<String> diveIds(int n) => [for (var i = 0; i < n; i++) 'dive-$i'];

  Future<void> insertDives(List<String> ids) => db.batch((b) {
    b.insertAll(db.dives, [
      for (final (i, id) in ids.indexed)
        DivesCompanion.insert(
          id: id,
          diveDateTime: epoch + i,
          createdAt: epoch,
          updatedAt: epoch,
        ),
    ]);
  });

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: Value(id),
          createdAt: const Value(epoch),
          updatedAt: const Value(epoch),
        ),
      );

  MediaItem photo(String name, {required String diveId, String? siteId}) =>
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        filePath: '/photos/$name',
        localPath: '/photos/$name',
        originalFilename: name,
        diveId: diveId,
        siteId: siteId,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      );

  Future<String> insertRoute({required String diveId}) =>
      NavTrackRepository().insertImportedRoute(
        points: [
          for (var i = 0; i < 2; i++)
            NavTrackPoint(
              timestamp: 1700000000 + i * 10,
              north: i * 10.0,
              east: 0,
              depth: 5,
              distance: i * 10.0,
              speed: 0.3,
            ),
        ],
        source: NavTrackSource.seacraftEnc,
        sourceRef: 'route.csv',
        diveId: diveId,
      );

  Future<void> insertEnrichment(String id, String mediaId, String diveId) => db
      .into(db.mediaEnrichment)
      .insert(
        MediaEnrichmentCompanion(
          id: Value(id),
          mediaId: Value(mediaId),
          diveId: Value(diveId),
          createdAt: const Value(epoch),
        ),
      );

  Future<List<String>> pendingIds(String entityType) async {
    final rows = await (db.select(
      db.syncRecords,
    )..where((t) => t.entityType.equals(entityType))).get();
    return [for (final r in rows) r.recordId];
  }

  Future<List<String>> tombstoneIds(String entityType) async {
    final rows = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals(entityType))).get();
    return [for (final r in rows) r.recordId];
  }

  /// [id] at both ends of a list that fills the first chunk, so it is bound
  /// in two chunks: one `IN (...)` over every id would match it once.
  List<String> listedTwiceAcrossChunks(String id) => [
    id,
    for (var i = 1; i < kSeriesIdChunkSize; i++) 'absent-$i',
    id,
  ];

  Future<int> countRows(String table) async {
    final row = await db
        .customSelect('SELECT COUNT(*) AS n FROM $table')
        .getSingle();
    return row.read<int>('n');
  }

  test(
    'bulkDeleteDives deletes more dives than one statement can bind, '
    'with one tombstone per dive',
    () async {
      final ids = diveIds(count);
      await insertDives(ids);
      await insertSite('site-1');
      // Dive-only media dies with its dive; site-linked media survives with
      // the dive link cleared. Both steps bind the dying dives' ids.
      final doomed = await mediaRepository.createMedia(
        photo('doomed.jpg', diveId: ids.first),
      );
      final kept = await mediaRepository.createMedia(
        photo('kept.jpg', diveId: ids.last, siteId: 'site-1'),
      );
      // A plan linked to a dive has its link cleared before the delete.
      await DivePlanRepository().savePlan(
        DivePlan(
          id: 'plan-1',
          name: 'plan-1',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
          gfLow: 30,
          gfHigh: 70,
          linkedDiveId: ids[count ~/ 2],
        ),
      );
      // A route linked to a dive past the first chunk is normalized as
      // unlinked afterwards.
      final routeId = await insertRoute(diveId: ids[kSeriesIdChunkSize + 1]);
      // The surviving photo's enrichment was computed against the dying dive,
      // so it goes, with a tombstone.
      await insertEnrichment('enrichment-1', kept.id, ids.last);
      // Only the delete's own sync marks remain for the assertions below.
      await db.customStatement('DELETE FROM sync_records');

      final deleted = await diveRepository.bulkDeleteDives(ids);

      expect(deleted, ids);
      expect(await countRows('dives'), 0);
      expect(await mediaRepository.getMediaById(doomed.id), isNull);
      final survivor = await mediaRepository.getMediaById(kept.id);
      expect(survivor, isNotNull);
      expect(survivor!.diveId, isNull);
      expect(survivor.siteId, 'site-1');
      final plan = await db
          .customSelect(
            "SELECT linked_dive_id FROM dive_plans WHERE id = 'plan-1'",
          )
          .getSingle();
      expect(plan.readNullable<String>('linked_dive_id'), isNull);
      expect(await pendingIds('divePlans'), ['plan-1']);
      final route = (await NavTrackRepository().getById(
        routeId,
        includePoints: false,
      ))!;
      expect(route.linkMode, isNull);
      expect(route.isPrimary, isTrue);
      expect(await pendingIds(NavTrackRepository.entityType), [routeId]);
      expect(await countRows('media_enrichment'), 0);
      expect(await tombstoneIds('mediaEnrichment'), ['enrichment-1']);
      expect(await pendingIds('media'), [kept.id]);
      expect(await tombstoneIds('media'), [doomed.id]);

      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.entityType.equals('dives'))).get();
      expect(tombstones.map((t) => t.recordId).toSet(), ids.toSet());
      expect(
        tombstones.map((t) => t.hlc).toSet(),
        hasLength(count),
        reason: 'each dive delete is its own event, with its own clock',
      );
      for (final t in tombstones) {
        expect(t.originHlc, t.hlc, reason: 'a local delete is its own origin');
      }
    },
    // Measured at 57.7 s in a full bundled run and 51 s alone with --coverage
    // on 2026-09-28, more than a third of testTimeLimit
    // (test/helpers/test_timeouts.dart). CI's 4-vCPU runners are slower than
    // that machine, so it gets five minutes.
    timeout: const Timeout(Duration(minutes: 5)),
  );

  test('getDivesByIds reads more ids than one statement can bind, '
      'newest first', () async {
    // Only a few of the ids exist: every id is still bound, and mapping a
    // full dive per row is not what this test is about.
    await insertDives(['old', 'mid', 'new']);
    final ids = [...diveIds(count), 'mid', 'old', 'new'];

    final dives = await diveRepository.getDivesByIds(ids);

    expect(dives.map((d) => d.id), ['new', 'mid', 'old']);
  });

  test('getDivesByIds breaks a time tie by dive number, highest first and '
      'unnumbered last', () async {
    // The sort moved from SQL to Dart with chunking, so it has to keep
    // SQLite's `dive_number DESC` order, which puts NULL last. Inserted
    // and requested in the reverse of that order, so only the tie-break
    // can produce it.
    await db.batch((b) {
      b.insertAll(db.dives, [
        for (final (id, number) in [
          ('unnumbered', null),
          ('one', 1),
          ('two', 2),
        ])
          DivesCompanion.insert(
            id: id,
            diveNumber: Value(number),
            diveDateTime: epoch,
            createdAt: epoch,
            updatedAt: epoch,
          ),
      ]);
    });

    final dives = await diveRepository.getDivesByIds([
      'unnumbered',
      'one',
      'two',
    ]);

    expect(dives.map((d) => d.id), ['two', 'one', 'unnumbered']);
  });

  group('an id listed twice across chunks comes back once', () {
    test('getDivesByIds', () async {
      await insertDives(['twice']);

      final dives = await diveRepository.getDivesByIds(
        listedTwiceAcrossChunks('twice'),
      );

      expect(dives.map((d) => d.id), ['twice']);
    });

    test('partitionMediaForDiveDeletion', () async {
      await insertDives(['twice']);
      final photoItem = await mediaRepository.createMedia(
        photo('a.jpg', diveId: 'twice'),
      );

      final split = await mediaRepository.partitionMediaForDiveDeletion(
        listedTwiceAcrossChunks('twice'),
      );

      expect(split.doomed.map((m) => m.id), [photoItem.id]);
    });

    test('routeIdsLinkedToDives', () async {
      await insertDives(['twice']);
      final routeId = await insertRoute(diveId: 'twice');

      final routeIds = await NavTrackRepository().routeIdsLinkedToDives(
        listedTwiceAcrossChunks('twice'),
      );

      expect(routeIds, [routeId]);
    });
  });
}
