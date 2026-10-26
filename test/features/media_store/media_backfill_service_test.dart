import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/media_store/media_store_attach_state.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart'
    as domain;
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_backfill_service.dart';
import 'package:submersion/features/media_store/data/media_stores_repository.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository mediaRepository;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaBackfillService service;

  setUp(() async {
    db = await setUpTestDatabase();
    // Backfill candidates must be linked to a dive or site; every fixture
    // row in this file hangs off this one dive.
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('dive-1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    mediaRepository = MediaRepository();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    queue = MediaTransferQueueRepository(database: cacheDb);
    service = MediaBackfillService(
      mediaRepository: mediaRepository,
      queue: queue,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<domain.MediaItem> mediaRow({
    required String name,
    domain.MediaType mediaType = domain.MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.localFile,
    DateTime? takenAt,
    DateTime? uploadedAt,
    String? storeId,
  }) async {
    final created = await mediaRepository.createMedia(
      domain.MediaItem(
        id: '',
        diveId: 'dive-1',
        mediaType: mediaType,
        sourceType: sourceType,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        takenAt: takenAt ?? DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (uploadedAt != null) {
      await mediaRepository.stampRemoteUploaded(
        created.id,
        uploadedAt: uploadedAt,
        storeId: storeId,
      );
    }
    return created;
  }

  test('enqueues device-resident photos and videos without a remote stamp, '
      'newest first, skipping signatures, network sources, and uploaded '
      'rows', () async {
    final old = await mediaRow(name: 'old.jpg', takenAt: DateTime(2025));
    final recent = await mediaRow(name: 'new.jpg', takenAt: DateTime(2026, 6));
    // Local videos upload their original, so an unstamped one is a
    // candidate. Excluding them would leave a permanent not-backed-up
    // badge on every locally imported video.
    final clip = await mediaRow(
      name: 'clip.mp4',
      mediaType: domain.MediaType.video,
    );
    await mediaRow(
      name: 'sig.png',
      mediaType: domain.MediaType.instructorSignature,
    );
    await mediaRow(name: 'net.jpg', sourceType: MediaSourceType.networkUrl);
    await mediaRow(name: 'up.jpg', uploadedAt: DateTime(2026, 7));

    final ids = await mediaRepository.getBackfillCandidateIds();
    expect(ids, [recent.id, clip.id, old.id]);

    expect(await service.enqueueAll(), 3);
    final rows = await queue.allForTesting();
    expect(rows.map((r) => r.mediaId).toSet(), {recent.id, clip.id, old.id});

    // Idempotent: re-running does not duplicate pending rows.
    expect(await service.enqueueAll(), 3);
    expect((await queue.allForTesting()).length, 3);
  });

  test('connector photos are candidates; connector videos key on the thumb '
      'stamp', () async {
    final photo = await mediaRow(
      name: 'lr.jpg',
      sourceType: MediaSourceType.serviceConnector,
    );
    final videoNoThumb = await mediaRow(
      name: 'lr1.mp4',
      mediaType: domain.MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
      takenAt: DateTime(2025, 12),
    );
    final videoWithThumb = await mediaRow(
      name: 'lr2.mp4',
      mediaType: domain.MediaType.video,
      sourceType: MediaSourceType.serviceConnector,
    );
    await mediaRepository.stampRemoteThumbUploaded(
      videoWithThumb.id,
      uploadedAt: DateTime(2026, 7),
    );
    // A device-resident video qualifies on the original stamp, on the
    // separate branch from the connector thumb rule. Distinct takenAt so
    // the newest-first ordering is deterministic rather than resolved by
    // an unstable tiebreak against the connector photo.
    final galleryVideo = await mediaRow(
      name: 'gal.mp4',
      mediaType: domain.MediaType.video,
      takenAt: DateTime(2025, 11),
    );

    final ids = await mediaRepository.getBackfillCandidateIds();
    expect(ids, [photo.id, videoNoThumb.id, galleryVideo.id]);
  });

  // Issue #3482: after a switch the attached store holds nothing, so rows
  // stamped in the old store are uploaded again.
  test('uploads what another store holds to the attached one', () async {
    SharedPreferences.setMockInitialValues({});
    final attachState = MediaStoreAttachState(
      prefs: await SharedPreferences.getInstance(),
    );
    await attachState.setAttached(
      'store-b',
      providerType: CloudProviderType.dropbox,
    );
    final elsewhere = await mediaRow(
      name: 'old.jpg',
      uploadedAt: DateTime(2026, 7),
      storeId: 'store-a',
    );
    await mediaRow(
      name: 'here.jpg',
      uploadedAt: DateTime(2026, 7),
      storeId: 'store-b',
    );

    final enqueued = await MediaBackfillService(
      mediaRepository: mediaRepository,
      queue: queue,
      attachState: attachState,
    ).enqueueAll();

    expect(enqueued, 1);
    expect((await queue.allForTesting()).single.mediaId, elsewhere.id);
  });
  // A switch leaves the old store's terminal failures behind; tapping
  // Upload everything must give them a fresh attempt budget against the
  // attached store, or they count as queued and never upload.
  test('re-arms a terminally failed upload row so it can be claimed', () async {
    final photo = await mediaRow(name: 'stuck.jpg');
    final id = await queue.enqueueUpload(mediaId: photo.id);
    for (var i = 0; i < 5; i++) {
      await queue.markFailed(id, 'insufficient space');
    }
    expect((await queue.allForTesting()).single.state, 'failed');

    expect(await service.enqueueAll(), 1);

    final row = (await queue.allForTesting()).single;
    expect(row.id, id);
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.errorMessage, isNull);
    final claimed = await queue.claimNextPending(DateTime.now());
    expect(claimed?.id, id);
    queue.release(id);
  });

  test('resets the attempt count of a pending upload row', () async {
    final photo = await mediaRow(name: 'retrying.jpg');
    final id = await queue.enqueueUpload(mediaId: photo.id);
    for (var i = 0; i < 4; i++) {
      await queue.markFailed(id, 'insufficient space');
    }

    expect(await service.enqueueAll(), 1);

    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending');
    expect(row.attempts, 0);
    expect(row.nextAttemptAt, isNull);
    expect(await queue.nextPending(DateTime.now()), isNotNull);
  });

  // Issue #3569: on a store the library no longer announces, rows another
  // device moved to the announced store are left alone.
  test(
    'a device on a store that is not announced leaves moved rows alone',
    () async {
      SharedPreferences.setMockInitialValues({});
      final attachState = MediaStoreAttachState(
        prefs: await SharedPreferences.getInstance(),
      );
      await attachState.setAttached(
        'store-a',
        providerType: CloudProviderType.dropbox,
      );
      final stores = MediaStoresRepository();
      await stores.upsertActive(
        storeId: 'store-b',
        providerType: 'dropbox',
        displayHint: 'Dropbox',
      );
      await mediaRow(
        name: 'moved.jpg',
        uploadedAt: DateTime(2026, 7),
        storeId: 'store-b',
      );
      final fresh = await mediaRow(name: 'fresh.jpg');

      final enqueued = await MediaBackfillService(
        mediaRepository: mediaRepository,
        queue: queue,
        attachState: attachState,
        stores: stores,
      ).enqueueAll();

      expect(enqueued, 1);
      expect((await queue.allForTesting()).single.mediaId, fresh.id);
    },
  );
}
