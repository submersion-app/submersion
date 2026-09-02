import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/presentation/providers/media_providers.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/presentation/providers/media_store_providers.dart';

import '../../helpers/test_database.dart';
import '../../helpers/wait_until.dart';

/// Counts label lookups so a test can tell one batched query from one per
/// queue emission.
class _CountingRepository extends MediaRepository {
  int calls = 0;

  @override
  Future<Map<String, String>> getDisplayLabels(Iterable<String> ids) {
    calls++;
    return super.getDisplayLabels(ids);
  }
}

/// Labels for the Transfers list: one query for the whole queue, re-run only
/// when the set of media the queue names changes (Copilot review on #1388:
/// a lookup per visible row re-ran on every media write and pinned a full
/// MediaItem per row for the container's lifetime).
void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late _CountingRepository media;
  late ProviderContainer container;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    media = _CountingRepository();
    container = ProviderContainer(
      overrides: [
        mediaTransferQueueRepositoryProvider.overrideWithValue(queue),
        mediaRepositoryProvider.overrideWithValue(media),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<String> insertMedia(String name) async {
    final created = await media.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    return created.id;
  }

  Map<String, String>? labels() =>
      container.read(mediaTransferLabelsProvider).value;

  test('names the queued media with one query, and re-queries only when the '
      'queue names different media', () async {
    final a = await insertMedia('a.jpg');
    final b = await insertMedia('b.jpg');
    final sub = container.listen(mediaTransferLabelsProvider, (_, _) {});
    addTearDown(sub.close);

    final entryA = await queue.enqueueUpload(mediaId: a);
    await waitUntil(() async => labels()?[a] == 'a.jpg');
    expect(media.calls, 1);

    // A state change re-emits the rows but names the same media.
    await queue.markTransferring(entryA);
    await waitUntil(
      () async =>
          container.read(mediaTransferEntriesProvider).value?.single.state ==
          'transferring',
    );
    expect(media.calls, 1);

    await queue.enqueueUpload(mediaId: b);
    await waitUntil(() async => labels()?[b] == 'b.jpg');
    expect(labels(), {a: 'a.jpg', b: 'b.jpg'});
    expect(media.calls, 2);
  });

  test('an empty queue resolves to no labels without querying', () async {
    final sub = container.listen(mediaTransferLabelsProvider, (_, _) {});
    addTearDown(sub.close);

    await waitUntil(() async => labels() != null);
    expect(labels(), isEmpty);
    expect(media.calls, 0);
  });

  // The pipeline stamps the media row of every completed upload, so a
  // subscription to the media table re-ran this query about three times a
  // second through a drain, over every id the queue had ever named.
  test('a write to the media table does not re-run the query', () async {
    final a = await insertMedia('a.jpg');
    final sub = container.listen(mediaTransferLabelsProvider, (_, _) {});
    addTearDown(sub.close);
    await queue.enqueueUpload(mediaId: a);
    await waitUntil(() async => labels()?[a] == 'a.jpg');
    expect(media.calls, 1);

    await insertMedia('c.jpg');
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(media.calls, 1);
    expect(labels(), {a: 'a.jpg'});
  });
}
