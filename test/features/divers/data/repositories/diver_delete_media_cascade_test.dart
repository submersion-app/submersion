import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/divers/data/repositories/diver_repository.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';

/// Deleting a diver cascades their media the way the single-entity deletes
/// do (issue #1954, media sync program spec 5.4). Media linked only to the
/// diver's dives, sites and gear is deleted, tombstoned, and its uploaded
/// copy queued for removal; media a surviving row still links is unlinked,
/// stamped and marked pending. Without this, the foreign keys' SET NULL
/// left every such row detached, unstamped and unsynced on every device.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late DiverRepository repository;
  const t = 1000;

  Future<void> insertDiver(String id, {bool isDefault = false}) => db
      .into(db.divers)
      .insert(
        DiversCompanion(
          id: Value(id),
          name: Value(id),
          isDefault: Value(isDefault),
          createdAt: const Value(t),
          updatedAt: const Value(t),
        ),
      );

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    repository = DiverRepository(
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => queue,
      ),
    );
    await insertDiver('diver-a', isDefault: true);
    // A survivor, so Step 0 reassigns the shared sites instead of deleting.
    await insertDiver('diver-b');
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id, String diverId) => db
      .into(db.dives)
      .insert(
        DivesCompanion.insert(
          id: id,
          diverId: Value(diverId),
          diveDateTime: t,
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> insertSite(String id, String diverId, {bool isShared = false}) =>
      db
          .into(db.diveSites)
          .insert(
            DiveSitesCompanion.insert(
              id: id,
              name: id,
              diverId: Value(diverId),
              isShared: Value(isShared),
              createdAt: t,
              updatedAt: t,
            ),
          );

  Future<void> insertGear(String id, String diverId) => db
      .into(db.equipment)
      .insert(
        EquipmentCompanion.insert(
          id: id,
          name: id,
          type: 'regulator',
          diverId: Value(diverId),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<void> insertBuddy(String id, String diverId) => db
      .into(db.buddies)
      .insert(
        BuddiesCompanion.insert(
          id: id,
          name: id,
          diverId: Value(diverId),
          createdAt: t,
          updatedAt: t,
        ),
      );

  Future<String> photo({
    String? dive,
    String? site,
    String? gear,
    String? signer,
  }) async => (await MediaRepository().createMedia(
    MediaItem(
      id: '',
      mediaType: MediaType.photo,
      sourceType: MediaSourceType.localFile,
      localPath: p.join('photos', 'p.jpg'),
      originalFilename: 'p.jpg',
      diveId: dive,
      siteId: site,
      equipmentId: gear,
      signerId: signer,
      takenAt: DateTime(2026, 1, 1),
      createdAt: DateTime(2026, 1, 1),
      updatedAt: DateTime(2026, 1, 1),
    ),
  )).id;

  /// Marks [id] as uploaded to a media store, so its deletion owes a
  /// blob-delete intent.
  Future<void> uploaded(String id) => db.customStatement(
    'UPDATE media SET content_hash = ?, remote_uploaded_at = 1 WHERE id = ?',
    ['hash-$id', id],
  );

  Future<MediaData?> row(String id) =>
      (db.select(db.media)..where((m) => m.id.equals(id))).getSingleOrNull();

  Future<int> tombstonesFor(String entityType, String recordId) async =>
      (await db
              .customSelect(
                'SELECT COUNT(*) AS n FROM deletion_log '
                'WHERE entity_type = ? AND record_id = ?',
                variables: [
                  Variable<String>(entityType),
                  Variable<String>(recordId),
                ],
              )
              .getSingle())
          .read<int>('n');

  Future<bool> isPending(String id) async =>
      (await SyncRepository().getPendingRecords()).any(
        (r) => r.entityType == 'media' && r.recordId == id,
      );

  Future<List<String>> blobDeletes() async => [
    for (final e in await queue.allForTesting())
      if (e.direction == 'delete') e.mediaId,
  ];

  test("a photo only the diver's dive shows is deleted everywhere", () async {
    await insertDive('d1', 'diver-a');
    final id = await photo(dive: 'd1');
    await uploaded(id);
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await row(id), isNull);
    expect(await tombstonesFor('media', id), 1);
    expect(await blobDeletes(), [
      id,
    ], reason: 'the uploaded copy must be scheduled for removal');
  });

  test("a photo on the diver's dive and private site goes with both", () async {
    await insertDive('d1', 'diver-a');
    await insertSite('s1', 'diver-a');
    final id = await photo(dive: 'd1', site: 's1');

    await repository.deleteDiverWithReassignment('diver-a');

    expect(await row(id), isNull, reason: 'neither parent survives');
  });

  test(
    'a photo on a shared site the survivor inherits outlives the delete',
    () async {
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      final id = await photo(dive: 'd1', site: 's1');
      await SyncRepository().clearPendingRecords();

      await repository.deleteDiverWithReassignment('diver-a');

      final kept = await row(id);
      expect(kept, isNotNull);
      expect(kept!.diveId, isNull);
      expect(kept.siteId, 's1');
      expect(await isPending(id), isTrue, reason: 'peers must take the unlink');
      expect(await tombstonesFor('media', id), 0);
    },
  );

  test(
    'with no surviving diver the shared site goes too, and its photo',
    () async {
      await db.customStatement("DELETE FROM divers WHERE id = 'diver-b'");
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      final id = await photo(dive: 'd1', site: 's1');

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await row(id), isNull);
    },
  );

  test(
    "gear paperwork another diver's dive uses loses only the gear link",
    () async {
      await insertDive('d-b', 'diver-b');
      await insertGear('g1', 'diver-a');
      final id = await photo(dive: 'd-b', gear: 'g1');
      await SyncRepository().clearPendingRecords();

      await repository.deleteDiverWithReassignment('diver-a');

      final kept = await row(id);
      expect(kept!.equipmentId, isNull);
      expect(kept.diveId, 'd-b');
      expect(await isPending(id), isTrue);
    },
  );

  test("a signature by the diver's buddy on another diver's dive loses only "
      'the signer', () async {
    await insertDive('d-b', 'diver-b');
    await insertBuddy('b1', 'diver-a');
    final id = await photo(dive: 'd-b', signer: 'b1');
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    final kept = await row(id);
    expect(kept!.signerId, isNull);
    expect(kept.diveId, 'd-b');
    expect(await isPending(id), isTrue);
  });

  test(
    "the enrichment the diver's dives take with them is tombstoned",
    () async {
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      final id = await photo(dive: 'd1', site: 's1');
      await db
          .into(db.mediaEnrichment)
          .insert(
            MediaEnrichmentCompanion.insert(
              id: 'e1',
              mediaId: id,
              diveId: 'd1',
              createdAt: t,
            ),
          );

      await repository.deleteDiverWithReassignment('diver-a');

      expect(await tombstonesFor('mediaEnrichment', 'e1'), 1);
    },
  );

  test("another diver's media is not touched", () async {
    await insertDive('d-b', 'diver-b');
    final id = await photo(dive: 'd-b');
    await db.customStatement('UPDATE media SET updated_at = 1 WHERE id = ?', [
      id,
    ]);
    await SyncRepository().clearPendingRecords();

    await repository.deleteDiverWithReassignment('diver-a');

    expect((await row(id))!.updatedAt, 1);
    expect(await isPending(id), isFalse);
  });

  test('a cleanup failure after the commit is logged, not rethrown', () async {
    // The diver is gone by then and cannot be restored, so reporting the
    // delete as failed would be a lie. What is left is recoverable: the row
    // stays, unlinked, for the orphan sweep.
    await insertDive('d1', 'diver-a');
    final id = await photo(dive: 'd1');

    await DiverRepository(
      mediaDeletionCoordinator: _FailingCoordinator(),
    ).deleteDiverWithReassignment('diver-a');

    final diver = await (db.select(
      db.divers,
    )..where((d) => d.id.equals('diver-a'))).getSingleOrNull();
    expect(diver, isNull);
    expect(await row(id), isNotNull, reason: 'left for the orphan sweep');
  });

  test(
    'without an injected coordinator the default one does the cascade',
    () async {
      // Most callers build a DiverRepository only to read the active diver,
      // so the default coordinator is built on first use. An uploaded row
      // makes it reach for its queue too.
      await insertDive('d1', 'diver-a');
      final id = await photo(dive: 'd1');
      await uploaded(id);

      await DiverRepository().deleteDiverWithReassignment('diver-a');

      expect(await row(id), isNull);
    },
  );

  test(
    'a failed deletion still publishes the unlinks of surviving media',
    () async {
      // The commit already cleared the survivor's dying link with SET NULL
      // and no stamp, and its live link keeps it out of every sweep. If this
      // write is lost, its peers keep the stale link for good.
      await insertDive('d1', 'diver-a');
      await insertSite('s1', 'diver-a', isShared: true);
      await photo(dive: 'd1');
      final survivor = await photo(dive: 'd1', site: 's1');
      await SyncRepository().clearPendingRecords();

      await DiverRepository(
        mediaDeletionCoordinator: _FailingCoordinator(),
      ).deleteDiverWithReassignment('diver-a');

      final kept = await row(survivor);
      expect(kept!.diveId, isNull);
      expect(kept.siteId, 's1');
      expect(await isPending(survivor), isTrue);
    },
  );

  test('a photo relinked while its deletion is under way is kept', () async {
    // The row is read again before deletion, but the coordinator awaits its
    // queue write before deleting by id, and a relink can land in between.
    // The liveness check has to travel with the delete itself.
    await insertDive('d1', 'diver-a');
    await insertDive('d-b', 'diver-b');
    final id = await photo(dive: 'd1');
    // Uploaded, so the coordinator writes to the queue: the relink lands
    // inside that write.
    await uploaded(id);
    final relinking = _RelinkingQueue(
      cacheDb,
      () => db.customStatement(
        "UPDATE media SET dive_id = 'd-b' WHERE id = ?",
        [id],
      ),
    );

    await DiverRepository(
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: MediaRepository(),
        queue: () => relinking,
      ),
    ).deleteDiverWithReassignment('diver-a');

    final kept = await row(id);
    expect(kept, isNotNull, reason: 'a surviving dive shows it now');
    expect(kept!.diveId, 'd-b');
    expect(await tombstonesFor('media', id), 0);
  });

  test('a delete that fails changes no media', () async {
    await insertDive('d1', 'diver-a');
    final id = await photo(dive: 'd1');
    await uploaded(id);
    await SyncRepository().clearPendingRecords();
    await db.customStatement(
      'CREATE TRIGGER fail_diver_delete BEFORE DELETE ON divers '
      "BEGIN SELECT RAISE(ABORT, 'boom'); END",
    );

    await expectLater(
      repository.deleteDiverWithReassignment('diver-a'),
      throwsA(anything),
    );

    expect((await row(id))!.diveId, 'd1');
    expect(await isPending(id), isFalse);
    expect(await blobDeletes(), isEmpty);
  });
}

/// Runs [relink] inside the coordinator's queue write, which is exactly the
/// window between its liveness recheck and its delete.
class _RelinkingQueue extends MediaTransferQueueRepository {
  _RelinkingQueue(LocalCacheDatabase database, this.relink)
    : super(database: database);

  final Future<void> Function() relink;

  @override
  Future<int> enqueueDelete({
    required String mediaId,
    required String contentHash,
    required String originalExt,
    required String renditionExt,
  }) async {
    await relink();
    return super.enqueueDelete(
      mediaId: mediaId,
      contentHash: contentHash,
      originalExt: originalExt,
      renditionExt: renditionExt,
    );
  }
}

/// Fails the way a media store problem after the commit would.
class _FailingCoordinator extends MediaDeletionCoordinator {
  _FailingCoordinator()
    : super(
        mediaRepository: MediaRepository(),
        queue: () => MediaTransferQueueRepository(),
      );

  @override
  Future<void> deleteMediaItems(
    List<MediaItem> items, {
    bool Function(MediaData row)? keepIf,
  }) async => throw StateError('media store unavailable');
}
