import 'dart:async';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';
import 'package:submersion/features/media_store/data/orphan_delete_policy.dart';
import 'package:submersion/core/database/local_cache_database.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

/// Lists a key once per stored copy, as Google Drive does when two devices
/// uploaded one key at the same moment; each delete removes one copy.
class _DuplicatingStore extends InMemoryMediaObjectStore
    implements DuplicateKeyStore {
  final copies = <String, int>{};

  /// Per-copy modification times, in listing order, where they differ.
  final copyModified = <String, List<DateTime>>{};

  @override
  Future<int> deleteExtraCopies(
    String key, {
    bool Function()? mayDelete,
  }) async {
    var removed = 0;
    while ((copies[key] ?? 1) > 1) {
      if (mayDelete != null && !mayDelete()) break;
      copies[key] = copies[key]! - 1;
      removed++;
    }
    return removed;
  }

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    await for (final info in super.list(keyPrefix)) {
      for (var i = 0; i < (copies[info.key] ?? 1); i++) {
        final times = copyModified[info.key];
        yield times == null
            ? info
            : StoreObjectInfo(
                key: info.key,
                sizeBytes: info.sizeBytes,
                lastModified: times[i],
              );
      }
    }
  }

  @override
  Future<void> delete(String key) async {
    final n = copies[key] ?? 1;
    if (n > 1) {
      copies[key] = n - 1;
      return;
    }
    copies.remove(key);
    await super.delete(key);
  }
}

/// Repeats every listed key, as a paged listing might, while holding one
/// object per key.
/// Records the prefix of every listing.
class _CountingStore extends InMemoryMediaObjectStore {
  final listedPrefixes = <String>[];

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) {
    listedPrefixes.add(keyPrefix);
    return super.list(keyPrefix);
  }
}

/// A store with a cheap local listing (as iCloud has), recording which
/// listing each sweep used.
class _LocalListingStore extends InMemoryMediaObjectStore
    implements LocalListingStore {
  final used = <String>[];

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) {
    used.add('list');
    return super.list(keyPrefix);
  }

  @override
  Stream<StoreObjectInfo> listLocal(String keyPrefix) {
    used.add('listLocal');
    return super.list(keyPrefix);
  }
}

class _RepeatingStore extends InMemoryMediaObjectStore {
  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    await for (final info in super.list(keyPrefix)) {
      yield info;
      yield info;
    }
  }
}

/// Lists objects without a size, as a provider that omits it would.
class _SizelessStore extends InMemoryMediaObjectStore {
  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    await for (final info in super.list(keyPrefix)) {
      yield StoreObjectInfo(key: info.key, lastModified: info.lastModified);
    }
  }
}

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
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
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

  test(
    'repair re-uploads an original present only under another extension',
    () async {
      // The resolver reads the exact key the row derives from its filename;
      // a sibling under another extension does not serve it.
      await insertDive('d1');
      final row = await photo(
        'a.jpg',
        hash: 'aabb',
        uploadedAt: DateTime(2026, 2),
      );
      seedObject(StoreKeys.objectKey('aabb', extension: 'jpeg'), modified: old);

      final report = await service.run();

      expect((await repo.getMediaById(row.id))!.remoteUploadedAt, isNull);
      expect(report.repairsQueued, 1);
    },
  );

  test(
    'repair re-uploads a rendition present only in the wrong format',
    () async {
      await insertDive('d1');
      final row = await photo(
        'a.jpg',
        hash: 'aabb',
        compressedAt: DateTime(2026, 2),
      );
      seedObject(StoreKeys.renditionKey('aabb', ext: 'mp4'), modified: old);

      final report = await service.run();

      expect(
        (await repo.getMediaById(row.id))!.remoteCompressedUploadedAt,
        isNull,
      );
      expect(report.repairsQueued, 1);
    },
  );

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
    // The total counts every stored object, so a library of N photos reads
    // as 2N or 3N; the breakdown is what makes that number explainable.
    expect(report.originalsChecked, 4);
    expect(report.thumbsChecked, 1);
    expect(report.renditionsChecked, 1);
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
      await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
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

  group('storage GC', () {
    test('lists the store once for every namespace', () async {
      // Most adapters list the whole folder whatever the prefix, so one
      // listing per namespace fetched the store three times.
      final counting = _CountingStore();
      counting.objects[StoreKeys.markerKey] = [1];
      counting.objects[StoreKeys.objectKey('aabb', extension: 'jpg')] = [1, 2];
      counting.objects[StoreKeys.thumbKey('aabb')] = [3];
      final sweep = MediaVerifyService(
        store: counting,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run(dryRun: true);

      expect(counting.listedPrefixes, ['smv1/']);
      expect(report.objectsChecked, 2, reason: 'the marker is not an object');
      expect(report.totalBytes, 3);
      expect(counting.objects.keys, contains(StoreKeys.markerKey));
    });

    test(
      'a measurement uses the local listing, a cleanup the full one',
      () async {
        final local = _LocalListingStore();
        final sweep = MediaVerifyService(
          store: local,
          mediaRepository: repo,
          queue: queue,
          now: () => now,
        );

        await sweep.run(dryRun: true);
        await sweep.run();

        expect(local.used, ['listLocal', 'list']);
      },
    );

    test('a key a listing repeats counts once in the total', () async {
      // Only a store that can hold copies has more than one; on any other a
      // repeat is a listing artefact.
      final repeating = _RepeatingStore();
      repeating.objects[StoreKeys.objectKey('aabb', extension: 'jpg')] = [1, 2];
      final sweep = MediaVerifyService(
        store: repeating,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run(dryRun: true);

      expect(report.totalBytes, 2);
    });

    test('a long sweep gives the event loop a turn', () async {
      // The classification passes are pure CPU between awaits; on a large
      // store they would freeze the UI isolate until the end.
      for (var i = 0; i < 1200; i++) {
        final hash = '${i.toRadixString(16).padLeft(4, '0')}ff';
        seedObject(StoreKeys.objectKey(hash, extension: 'jpg'), modified: old);
      }
      var finished = false;
      bool? timerRanDuringSweep;

      await service.run(
        dryRun: true,
        onProgress: (checked) {
          if (checked == 1200) {
            Timer.run(() => timerRanDuringSweep = !finished);
          }
        },
      );
      finished = true;
      await Future<void>.delayed(Duration.zero);

      expect(timerRanDuringSweep, isTrue);
    });

    test('stops deleting once the delete guard turns false', () async {
      // A sync that starts mid-sweep may bring rows the sweep's reference
      // snapshot does not have; nothing may be deleted after that.
      await insertDive('d1');
      await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      seedObject(StoreKeys.objectKey('dead1', extension: 'jpg'), modified: old);
      seedObject(StoreKeys.objectKey('dead2', extension: 'jpg'), modified: old);
      var allowed = true;
      store.onDelete = (_) => allowed = false;

      final report = await service.run(deleteGuard: () => allowed);

      expect(report.orphansRemoved, 1);
      expect(
        report.deferred,
        isTrue,
        reason: 'a stopped run is not a completed fleet sweep',
      );
      expect(store.objects.keys.where((k) => k.contains('dead')), hasLength(1));
    });

    test(
      'a database that references nothing in the store deletes nothing',
      () async {
        // A fresh or reset dive log with the store still attached: every object
        // looks unreferenced, and deleting them would empty the shared store.
        await insertDive('d1');
        seedObject(
          StoreKeys.objectKey('dead', extension: 'jpg'),
          modified: old,
        );

        final report = await service.run();

        expect(store.objects, isNotEmpty);
        expect(report.orphansRemoved, 0);
        expect(report.deferred, isTrue);
        expect(report.waitingBytes, 3);
      },
    );

    test(
      'a guard that is false from the start reports the run deferred',
      () async {
        await insertDive('d1');
        await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
        seedObject(
          StoreKeys.objectKey('dead', extension: 'jpg'),
          modified: old,
        );

        final report = await service.run(deleteGuard: () => false);

        expect(report.orphansRemoved, 0);
        expect(report.deferred, isTrue);
      },
    );

    test('a deferred run leaves upload stamps alone', () async {
      // Reverse repair clears synced stamps; on a database that is not
      // caught up that would override facts a peer changed since.
      await insertDive('d1');
      final item = await photo(
        'missing.jpg',
        hash: 'cc11',
        uploadedAt: DateTime(2026, 2),
      );

      final report = await service.run(
        policy: OrphanDeletePolicy(now: now, syncEnabled: true),
      );

      expect(report.repairsQueued, 0);
      expect((await repo.getMediaById(item.id))!.remoteUploadedAt, isNotNull);
    });

    test('dry run deletes nothing and reports reclaimable bytes', () async {
      await insertDive('d1');
      await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      seedObject(StoreKeys.objectKey('dead', extension: 'jpg'), modified: old);
      store.staleSessionCount = 2;

      final report = await service.run(dryRun: true);

      expect(
        store.objects.keys,
        contains(StoreKeys.objectKey('dead', extension: 'jpg')),
      );
      expect(report.orphansRemoved, 0);
      expect(report.bytesReclaimed, 0);
      expect(report.reclaimableBytes, 3);
      expect(report.sessionsAborted, 0, reason: 'a dry run reaps nothing');
    });

    test('deferred policy deletes nothing and reports waiting bytes', () async {
      await insertDive('d1');
      seedObject(StoreKeys.objectKey('dead', extension: 'jpg'), modified: old);

      final report = await service.run(
        policy: OrphanDeletePolicy(now: now, syncEnabled: true),
      );

      expect(report.deferred, isTrue);
      expect(report.orphansRemoved, 0);
      expect(report.reclaimableBytes, 0);
      expect(report.waitingBytes, 3);
    });

    test(
      'deletes an unreferenced extension sibling past the grace window',
      () async {
        await insertDive('d1');
        await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
        final kept = StoreKeys.objectKey('aabb', extension: 'jpg');
        final sibling = StoreKeys.objectKey('aabb', extension: 'jpeg');
        final staleRendition = StoreKeys.renditionKey('aabb', ext: 'jpg');
        seedObject(kept, modified: old);
        seedObject(sibling, modified: old);
        seedObject(staleRendition, modified: old);

        final report = await service.run();

        expect(store.objects.keys, contains(kept));
        expect(store.objects.keys, isNot(contains(sibling)));
        expect(store.objects.keys, isNot(contains(staleRendition)));
        expect(report.orphansRemoved, 2);
      },
    );

    test('keeps a sibling a pending row still needs', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      // Same bytes under another name, upload not finished: no stamp yet.
      await photo('b.jpeg', hash: 'aabb');
      final sibling = StoreKeys.objectKey('aabb', extension: 'jpeg');
      seedObject(StoreKeys.objectKey('aabb', extension: 'jpg'), modified: old);
      seedObject(sibling, modified: old);

      final report = await service.run();

      expect(store.objects.keys, contains(sibling));
      expect(report.orphansRemoved, 0);
    });

    test('keeps a sibling when it is the only copy of the photo', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      // The row's own key is missing; the resolver can still fall back to
      // this variant, so it must not be deleted.
      final onlyCopy = StoreKeys.objectKey('aabb', extension: 'jpeg');
      seedObject(onlyCopy, modified: old);

      final report = await service.run();

      expect(store.objects.keys, contains(onlyCopy));
      expect(report.orphansRemoved, 0);
    });

    test('deletes extra copies of a duplicated key and keeps one', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final dup = _DuplicatingStore();
      final key = StoreKeys.objectKey('aabb', extension: 'jpg');
      dup.objects[key] = List.filled(3, 7);
      dup.modified[key] = old;
      dup.copies[key] = 3;
      final sweep = MediaVerifyService(
        store: dup,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run();

      expect(dup.objects.keys, contains(key));
      expect(dup.copies[key], 1, reason: 'one copy left');
      expect(report.orphansRemoved, 2);
      expect(report.totalBytes, 9);
    });

    test('a sync that starts between duplicate deletes stops them', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final dup = _DuplicatingStore();
      final key = StoreKeys.objectKey('aabb', extension: 'jpg');
      dup.objects[key] = List.filled(3, 7);
      dup.modified[key] = old;
      dup.copies[key] = 4;
      final sweep = MediaVerifyService(
        store: dup,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );
      // Quiet for the up-front check, the per-key check and the first copy;
      // a sync starts before the second.
      var asked = 0;

      final report = await sweep.run(deleteGuard: () => ++asked <= 3);

      expect(dup.copies[key], 3, reason: 'one copy went before the sync');
      expect(report.orphansRemoved, 1);
    });

    test('an orphan with a fresh copy is not deleted for an old one', () async {
      // Copies are listed in no particular order; judged by the first, a
      // copy uploaded minutes ago would go with an old one.
      await insertDive('d1');
      await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final dup = _DuplicatingStore();
      final kept = StoreKeys.objectKey('aabb', extension: 'jpg');
      dup.objects[kept] = [1];
      dup.modified[kept] = old;
      final key = StoreKeys.objectKey('dead', extension: 'jpg');
      dup.objects[key] = List.filled(3, 7);
      dup.copies[key] = 2;
      dup.copyModified[key] = [old, now.subtract(const Duration(hours: 1))];
      final sweep = MediaVerifyService(
        store: dup,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run();

      expect(dup.copies[key], 2, reason: 'the fresh copy is in its grace');
      expect(report.orphansRemoved, 0);
    });

    test('a store that cannot hold duplicates is never asked to', () async {
      // A listing that repeats a key on S3 is a listing artefact, not two
      // objects: deleting "the extra copy" would delete the only one.
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final repeating = _RepeatingStore();
      final key = StoreKeys.objectKey('aabb', extension: 'jpg');
      repeating.objects[key] = List.filled(3, 7);
      repeating.modified[key] = old;
      final sweep = MediaVerifyService(
        store: repeating,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run();

      expect(repeating.objects.keys, contains(key));
      expect(report.orphansRemoved, 0);
    });

    test('a repeated orphan on a plain store is counted once', () async {
      await insertDive('d1');
      await photo('kept.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final repeating = _RepeatingStore();
      final key = StoreKeys.objectKey('dead', extension: 'jpg');
      repeating.objects[key] = List.filled(3, 7);
      repeating.modified[key] = old;
      final sweep = MediaVerifyService(
        store: repeating,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run();

      expect(repeating.objects.keys, isNot(contains(key)));
      expect(report.orphansRemoved, 1);
      expect(report.bytesReclaimed, 3);
    });

    test('duplicates wait while deletes are deferred', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final dup = _DuplicatingStore();
      final key = StoreKeys.objectKey('aabb', extension: 'jpg');
      dup.objects[key] = List.filled(3, 7);
      dup.modified[key] = old;
      dup.copies[key] = 2;
      final sweep = MediaVerifyService(
        store: dup,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      await sweep.run(policy: OrphanDeletePolicy(now: now, syncEnabled: true));

      expect(dup.copies[key], 2);
    });

    test('a key listed once is never deleted as a duplicate', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      final key = StoreKeys.objectKey('aabb', extension: 'jpg');
      seedObject(key, modified: old);

      final report = await service.run();

      expect(store.objects.keys, contains(key));
      expect(report.orphansRemoved, 0);
    });

    test('an object without a size marks the totals incomplete', () async {
      await insertDive('d1');
      final sizeless = _SizelessStore();
      sizeless.objects[StoreKeys.objectKey('dead', extension: 'jpg')] = [1];
      sizeless.modified[StoreKeys.objectKey('dead', extension: 'jpg')] = old;
      final sweep = MediaVerifyService(
        store: sizeless,
        mediaRepository: repo,
        queue: queue,
        now: () => now,
      );

      final report = await sweep.run(dryRun: true);

      expect(report.sizesUnknown, isTrue);
    });

    test('totalBytes sums every listed object', () async {
      await insertDive('d1');
      await photo('a.jpg', hash: 'aabb', uploadedAt: DateTime(2026, 2));
      seedObject(StoreKeys.objectKey('aabb', extension: 'jpg'), modified: old);
      seedObject(StoreKeys.thumbKey('aabb'), modified: old, size: 5);
      seedObject(
        StoreKeys.objectKey('f00d', extension: 'jpg'),
        modified: now.subtract(const Duration(hours: 1)),
        size: 7,
      );

      final report = await service.run();

      expect(report.totalBytes, 15);
      expect(report.waitingBytes, 7);
    });
  });
}
