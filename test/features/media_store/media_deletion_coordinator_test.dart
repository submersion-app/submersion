import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository repo;
  late int kicks;
  late MediaDeletionCoordinator coordinator;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    repo = MediaRepository();
    kicks = 0;
    coordinator = MediaDeletionCoordinator(
      mediaRepository: repo,
      queue: () => queue,
      kickWorker: () async => kicks++,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  MediaItem photo(
    String id, {
    String? hash,
    DateTime? uploadedAt,
    MediaType mediaType = MediaType.photo,
  }) => MediaItem(
    id: id,
    mediaType: mediaType,
    originalFilename: 'p.jpeg',
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
  );

  test('enqueues delete intent, then deletes the row, then kicks', () async {
    await repo.createMedia(
      photo('m1', hash: 'aa', uploadedAt: DateTime(2026, 2)),
    );
    await coordinator.deleteMedia('m1');
    expect(await repo.getMediaById('m1'), isNull);
    final row = (await queue.allForTesting()).single;
    expect(row.direction, 'delete');
    expect(row.contentHash, 'aa');
    expect(row.payloadJson, contains('"originalExt":"jpeg"'));
    expect(row.payloadJson, contains('"renditionExt":"jpg"'));
    expect(kicks, 1);
  });

  test('videos record an mp4 rendition extension', () async {
    await repo.createMedia(
      photo(
        'v1',
        hash: 'bb',
        uploadedAt: DateTime(2026, 2),
        mediaType: MediaType.video,
      ),
    );
    await coordinator.deleteMedia('v1');
    expect(
      (await queue.allForTesting()).single.payloadJson,
      contains('"renditionExt":"mp4"'),
    );
  });

  test('never-uploaded and hashless rows delete without enqueueing', () async {
    await repo.createMedia(photo('m2', hash: 'bb')); // hash, no stamp
    await repo.createMedia(photo('m3')); // no hash
    await coordinator.deleteMultipleMedia(['m2', 'm3']);
    expect(await repo.getMediaById('m2'), isNull);
    expect(await repo.getMediaById('m3'), isNull);
    expect(await queue.allForTesting(), isEmpty);
    expect(kicks, 0);
  });

  test('a thumb-only stamp still triggers the delete intent', () async {
    await repo.createMedia(photo('t1', hash: 'cc'));
    await repo.stampRemoteThumbUploaded('t1', uploadedAt: DateTime(2026, 2));
    await coordinator.deleteMedia('t1');
    expect((await queue.allForTesting()).single.direction, 'delete');
  });

  test('deleteMediaItems builds the intent from the caller\'s row', () async {
    await repo.createMedia(
      photo('m5', hash: 'dd', uploadedAt: DateTime(2026, 2)),
    );
    final held = (await repo.getMediaById('m5'))!;

    await coordinator.deleteMediaItems([held]);

    expect(await repo.getMediaById('m5'), isNull);
    final row = (await queue.allForTesting()).single;
    expect(row.direction, 'delete');
    expect(row.contentHash, 'dd');
    expect(kicks, 1);
  });

  test('deleteMediaItems does not read the row back', () async {
    // The dive-deletion cascade hands over rows it already selected, so the
    // per-id read must be skipped rather than merely redundant. Proven by
    // an item with no row behind it: the read-back path would find nothing
    // and enqueue nothing, so an intent here can only have come from the
    // caller's copy.
    await coordinator.deleteMediaItems([
      photo('ghost', hash: 'ee', uploadedAt: DateTime(2026, 2)),
    ]);

    final row = (await queue.allForTesting()).single;
    expect(row.contentHash, 'ee');
  });

  test('queue failure never blocks row deletion', () async {
    await repo.createMedia(
      photo('m4', hash: 'cc', uploadedAt: DateTime(2026, 2)),
    );
    final broken = MediaDeletionCoordinator(
      mediaRepository: repo,
      queue: () => throw StateError('cache db not initialized'),
      kickWorker: () async => kicks++,
    );
    await broken.deleteMedia('m4');
    expect(await repo.getMediaById('m4'), isNull);
  });
}
