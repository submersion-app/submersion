import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';
import 'package:submersion/core/services/media_store/network_status_service.dart';
import 'package:submersion/core/database/local_cache_database.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

class _ReapThrowingStore extends InMemoryMediaObjectStore {
  @override
  Future<int> reapStaleUploadSessions({required DateTime olderThan}) async {
    throw Exception('list-uploads unavailable');
  }
}

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository repo;
  late InMemoryMediaObjectStore store;
  late MediaVerifyService service;

  final now = DateTime.utc(2026, 7, 23);
  final old = now.subtract(const Duration(days: 30));

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    repo = MediaRepository();
    store = InMemoryMediaObjectStore();
    service = MediaVerifyService(
      store: store,
      mediaRepository: repo,
      queue: queue,
      now: () => now,
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<void> insertDive(String id) async {
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: Value(id),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
  }

  Future<MediaItem> photo(
    String name, {
    required String hash,
    DateTime? uploadedAt,
    DateTime? thumbAt,
    DateTime? compressedAt,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.platformGallery,
        filePath: '/tmp/$name',
        localPath: '/tmp/$name',
        originalFilename: name,
        diveId: 'd1',
        contentHash: hash,
        takenAt: DateTime(2026, 1, 1),
        createdAt: DateTime(2026, 1, 1),
        updatedAt: DateTime(2026, 1, 1),
      ),
    );
    if (uploadedAt != null) {
      await repo.stampRemoteUploaded(created.id, uploadedAt: uploadedAt);
    }
    if (thumbAt != null) {
      await repo.stampRemoteThumbUploaded(created.id, uploadedAt: thumbAt);
    }
    if (compressedAt != null) {
      await repo.stampRemoteCompressedUploaded(
        created.id,
        uploadedAt: compressedAt,
        level: 'balanced',
        sizeBytes: 10,
      );
    }
    return created;
  }

  void seedObject(String key, {required DateTime modified, int size = 3}) {
    store.objects[key] = List.filled(size, 7);
    store.modified[key] = modified;
  }

  test('deletes old unreferenced objects across all three namespaces, '
      'sparing referenced, young, and marker objects', () async {
    await insertDive('d1');
    await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));

    // Referenced (survives), old orphan in each namespace (dies), young
    // orphan (grace window), and the store marker (never touched).
    final keptKey = StoreKeys.objectKey('aabb', extension: 'jpg');
    seedObject(keptKey, modified: old);
    seedObject(StoreKeys.objectKey('dead', extension: 'jpg'), modified: old);
    seedObject(StoreKeys.thumbKey('dead'), modified: old, size: 5);
    seedObject(StoreKeys.renditionKey('dead', ext: 'jpg'), modified: old);
    seedObject(
      StoreKeys.objectKey('f00d', extension: 'jpg'),
      modified: now.subtract(const Duration(hours: 1)),
    );
    seedObject(StoreKeys.markerKey, modified: old);
    // Old and unreferenced, but not content-addressed shaped: never deleted.
    seedObject('smv1/objects/zz/not-a-hash.jpg', modified: old);

    final report = await service.run();

    expect(store.objects.keys, contains(keptKey));
    expect(store.objects.keys, contains(StoreKeys.markerKey));
    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('f00d', extension: 'jpg')),
      reason: 'young orphan is protected by the grace window',
    );
    expect(
      store.objects.keys,
      contains('smv1/objects/zz/not-a-hash.jpg'),
      reason: 'malformed keys are never deleted',
    );
    expect(
      store.objects.keys,
      isNot(contains(StoreKeys.objectKey('dead', extension: 'jpg'))),
    );
    expect(store.objects.keys, isNot(contains(StoreKeys.thumbKey('dead'))));
    expect(report.orphansRemoved, 3);
    expect(report.bytesReclaimed, 11); // 3 + 5 + 3
    expect(report.objectsChecked, 6); // marker is outside the namespaces
    expect(report.repairsQueued, 0);
  });

  test(
    'reverse repair clears the stale stamp and queues a re-upload',
    () async {
      await insertDive('d1');
      final missingOriginal = await photo(
        'missing.jpg',
        hash: 'cc11',
        uploadedAt: DateTime(2026, 2),
        thumbAt: DateTime(2026, 2),
      );
      // Thumb object exists; original object is absent from the store.
      seedObject(StoreKeys.thumbKey('cc11'), modified: old);

      final report = await service.run();

      final got = await repo.getMediaById(missingOriginal.id);
      expect(got!.remoteUploadedAt, isNull, reason: 'stale stamp cleared');
      expect(got.remoteThumbUploadedAt, isNotNull, reason: 'thumb is present');
      expect(report.repairsQueued, 1);
      final entry = (await queue.allForTesting()).single;
      expect(entry.direction, 'upload');
      expect(entry.mediaId, missingOriginal.id);
    },
  );

  test('a failing object delete is best-effort within the sweep', () async {
    await insertDive('d1');
    seedObject(StoreKeys.objectKey('dead', extension: 'jpg'), modified: old);
    store.failDeleteWith = Exception('delete refused');
    final report = await service.run();
    expect(report.orphansRemoved, 0);
    expect(
      store.objects.keys,
      contains(StoreKeys.objectKey('dead', extension: 'jpg')),
    );
  });

  test(
    'reverse repair clears thumb and rendition stamps independently',
    () async {
      await insertDive('d1');
      final item = await photo(
        'tiers.jpg',
        hash: 'ee33',
        thumbAt: DateTime(2026, 2),
        compressedAt: DateTime(2026, 2),
      );
      // Neither the thumb nor the rendition object exists in the store.
      final report = await service.run();
      final got = await repo.getMediaById(item.id);
      expect(got!.remoteThumbUploadedAt, isNull);
      expect(got.remoteCompressedUploadedAt, isNull);
      expect(report.repairsQueued, 1);
    },
  );

  test('reverse repair re-arms a terminally failed upload row', () async {
    await insertDive('d1');
    final item = await photo(
      'stuck.jpg',
      hash: 'dd22',
      uploadedAt: DateTime(2026, 2),
    );
    final rowId = await queue.enqueueUpload(mediaId: item.id);
    for (var i = 0; i < 5; i++) {
      await queue.markFailed(rowId, 'boom');
    }
    expect((await queue.allForTesting()).single.state, 'failed');

    final report = await service.run(); // original object absent -> repair

    expect(report.repairsQueued, 1);
    final row = (await queue.allForTesting()).single;
    expect(row.id, rowId);
    expect(row.state, 'pending', reason: 'repair re-arms the failed row');
  });

  test(
    'a failing session reap is best-effort: the sweep still succeeds',
    () async {
      await insertDive('d1');
      seedObject(StoreKeys.objectKey('dead', extension: 'jpg'), modified: old);
      final throwingStore = _ReapThrowingStore()
        ..objects.addAll(store.objects)
        ..modified.addAll(store.modified);
      final failing = MediaVerifyService(
        store: throwingStore,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );
      final report = await failing.run();
      expect(report.orphansRemoved, 1, reason: 'earlier cleanup still counts');
      expect(report.sessionsAborted, 0);
    },
  );

  test('sessionsAborted passes through the store reap', () async {
    store.staleSessionCount = 2;
    final report = await service.run();
    expect(report.sessionsAborted, 2);
  });

  group('shouldAutoVerify', () {
    final now = DateTime.utc(2026, 7, 23);

    test('never swept + unmetered runs', () {
      expect(
        shouldAutoVerify(
          lastSweepAt: null,
          network: NetworkKind.unmetered,
          now: now,
        ),
        isTrue,
      );
    });

    test('stale sweep + unmetered runs', () {
      expect(
        shouldAutoVerify(
          lastSweepAt: now.subtract(const Duration(days: 31)),
          network: NetworkKind.unmetered,
          now: now,
        ),
        isTrue,
      );
    });

    test('fresh sweep skips', () {
      expect(
        shouldAutoVerify(
          lastSweepAt: now.subtract(const Duration(days: 5)),
          network: NetworkKind.unmetered,
          now: now,
        ),
        isFalse,
      );
    });

    test('a slightly-future stamp reads as freshly swept and skips', () {
      expect(
        shouldAutoVerify(
          lastSweepAt: now.add(const Duration(hours: 2)),
          network: NetworkKind.unmetered,
          now: now,
        ),
        isFalse,
      );
    });

    test('a far-future stamp is bogus clock skew and does not suppress', () {
      expect(
        shouldAutoVerify(
          lastSweepAt: now.add(const Duration(days: 90)),
          network: NetworkKind.unmetered,
          now: now,
        ),
        isTrue,
      );
    });

    test('cellular and offline never run', () {
      for (final kind in [NetworkKind.cellular, NetworkKind.offline]) {
        expect(
          shouldAutoVerify(lastSweepAt: null, network: kind, now: now),
          isFalse,
        );
      }
    });
  });

  test('onProgress reports monotonically increasing counts', () async {
    await insertDive('d1');
    seedObject(StoreKeys.objectKey('x1', extension: 'jpg'), modified: old);
    seedObject(StoreKeys.thumbKey('x2'), modified: old);
    final seen = <int>[];
    await service.run(onProgress: seen.add);
    expect(seen, isNotEmpty);
    expect(seen.last, 2);
    for (var i = 1; i < seen.length; i++) {
      expect(seen[i], greaterThanOrEqualTo(seen[i - 1]));
    }
  });
}
