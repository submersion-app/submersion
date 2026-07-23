import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_delete_processor.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository mediaRepository;
  late InMemoryMediaObjectStore store;
  late MediaDeleteProcessor processor;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    mediaRepository = MediaRepository();
    store = InMemoryMediaObjectStore();
    processor = MediaDeleteProcessor(
      queue: queue,
      store: store,
      mediaRepository: mediaRepository,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  const hash = 'aabbccdd';
  final originalKey = StoreKeys.objectKey(hash, extension: 'jpg');
  final thumbKey = StoreKeys.thumbKey(hash);
  final renditionKey = StoreKeys.renditionKey(hash, ext: 'jpg');

  Future<MediaTransferQueueEntry> deleteEntry() async {
    final id = await queue.enqueueDelete(
      mediaId: 'gone',
      contentHash: hash,
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    return (await queue.allForTesting()).firstWhere((r) => r.id == id);
  }

  test('deletes all three tiers and marks done when hash is unreferenced',
      () async {
    store.objects[originalKey] = [1, 2, 3];
    store.objects[thumbKey] = [4];
    store.objects[renditionKey] = [5];
    await processor.process(await deleteEntry());
    expect(store.objects, isEmpty);
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('skips deletion when any row still references the hash', () async {
    await mediaRepository.createMedia(
      MediaItem(
        id: 'still-here',
        mediaType: MediaType.photo,
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
        contentHash: hash,
      ),
    );
    store.objects[originalKey] = [1];
    await processor.process(await deleteEntry());
    expect(store.objects.keys, contains(originalKey));
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('store failure marks the entry failed for retry', () async {
    store.objects[originalKey] = [1];
    store.failDeleteWith = Exception('boom');
    await processor.process(await deleteEntry());
    final row = (await queue.allForTesting()).single;
    expect(row.state, 'pending'); // attempt 1 of 5, backoff scheduled
    expect(row.attempts, 1);
    expect(row.errorMessage, contains('boom'));
  });

  test('malformed payload still deletes the thumb via fallback defaults',
      () async {
    final entryBefore = await deleteEntry();
    // Corrupt the payload behind the repository's back.
    await (cacheDb.update(cacheDb.mediaTransferQueue)
          ..where((t) => t.id.equals(entryBefore.id)))
        .write(const MediaTransferQueueCompanion(payloadJson: Value('nope')));
    store.objects[thumbKey] = [4];
    final entry = (await queue.allForTesting()).single;
    await processor.process(entry);
    expect(store.objects, isEmpty);
    expect((await queue.allForTesting()).single.state, 'done');
  });

  test('an entry without a content hash completes without touching the store',
      () async {
    final id = await queue.enqueueDelete(
      mediaId: 'gone',
      contentHash: 'temp',
      originalExt: 'jpg',
      renditionExt: 'jpg',
    );
    await (cacheDb.update(cacheDb.mediaTransferQueue)
          ..where((t) => t.id.equals(id)))
        .write(const MediaTransferQueueCompanion(contentHash: Value(null)));
    store.objects[thumbKey] = [4];
    await processor.process((await queue.allForTesting()).single);
    expect(store.objects.keys, contains(thumbKey));
    expect((await queue.allForTesting()).single.state, 'done');
  });
}
