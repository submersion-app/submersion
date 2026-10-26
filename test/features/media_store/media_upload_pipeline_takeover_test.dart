// Issue #3569: a device on a store the library no longer announces does not
// re-upload rows stamped in another store, so it never erases the announced
// store's record and the two devices never trade the row back and forth.

import 'dart:io';
import 'dart:ui' show Size;

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/media_source_resolver_registry.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_source_resolver.dart';
import 'package:submersion/features/media/domain/value_objects/media_source_data.dart';
import 'package:submersion/features/media/domain/value_objects/verify_result.dart';
import 'package:submersion/features/media_store/data/media_cache_store.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_upload_pipeline.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

/// Serves one local file for every row.
class _FileResolver implements MediaSourceResolver {
  _FileResolver(this.file);
  final File file;

  @override
  MediaSourceType get sourceType => MediaSourceType.localFile;

  @override
  bool canResolveOnThisDevice(MediaItem item) => true;

  @override
  Future<MediaSourceData> resolve(MediaItem item) async => FileData(file: file);

  @override
  Future<MediaSourceData> resolveThumbnail(
    MediaItem item, {
    required Size target,
  }) async => FileData(file: file);

  @override
  Future<VerifyResult> verify(MediaItem item) async => VerifyResult.available;
}

/// Lands another device's sync during the first transfer, as a takeover
/// that arrives while this device's upload is in flight.
class _SyncLandsDuringTransfer extends InMemoryMediaObjectStore {
  _SyncLandsDuringTransfer(this._sync);
  Future<void> Function()? _sync;

  @override
  Future<void> putFile(
    String key,
    File source, {
    required String contentType,
    TransferProgressCallback? onProgress,
    String? resumeStateJson,
    void Function(String resumeStateJson)? onResumeStateChanged,
  }) async {
    await super.putFile(
      key,
      source,
      contentType: contentType,
      onProgress: onProgress,
      resumeStateJson: resumeStateJson,
      onResumeStateChanged: onResumeStateChanged,
    );
    final sync = _sync;
    _sync = null;
    await sync?.call();
  }
}

void main() {
  late AppDatabase db;
  late MediaRepository repo;
  late LocalCacheDatabase cacheDb;
  late Directory root;
  late MediaTransferQueueRepository queue;

  setUp(() async {
    db = await setUpTestDatabase();
    repo = MediaRepository();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    root = await Directory.systemTemp.createTemp('pipeline_takeover');
    queue = MediaTransferQueueRepository(database: cacheDb);
    final epoch = DateTime(2026).millisecondsSinceEpoch;
    await db
        .into(db.dives)
        .insert(
          DivesCompanion(
            id: const Value('d1'),
            diveDateTime: Value(epoch),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
  });

  tearDown(() async {
    await cacheDb.close();
    if (root.existsSync()) await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  test('a device on a store that is not announced skips a row stamped '
      'elsewhere', () async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: 'moved.jpg',
        localPath: 'moved.jpg',
        originalFilename: 'moved.jpg',
        diveId: 'd1',
        contentHash: 'h1',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.stampRemoteUploaded(
      created.id,
      uploadedAt: DateTime.utc(2026),
      storeId: 'store-b',
    );
    await queue.enqueueUpload(mediaId: created.id);
    final store = InMemoryMediaObjectStore();

    final outcome = await MediaUploadPipeline(
      mediaRepository: repo,
      queue: queue,
      store: store,
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: _FileResolver(File('unused')),
      }),
      cache: MediaCacheStore(database: cacheDb, root: root),
      storeId: 'store-a',
      takesOver: () async => false,
    ).process((await queue.nextPending(DateTime.now()))!);

    expect(outcome, UploadOutcome.leftToAnotherStore);
    expect(store.objects, isEmpty);
    final after = (await repo.getMediaById(created.id))!;
    expect(after.remoteStoreId, 'store-b');
    expect(after.remoteUploadedAt, isNotNull);
  });

  // Issue #3569 review: the library can move to another store while this
  // upload stages and transfers; the stamp it ends with must not undo that.
  test('a takeover that lands mid-upload keeps the announced store\'s '
      'stamps', () async {
    final file = File(p.join(root.path, 'fresh.jpg'))
      ..writeAsBytesSync([1, 2, 3, 4]);
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: file.path,
        localPath: file.path,
        originalFilename: 'fresh.jpg',
        diveId: 'd1',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await queue.enqueueUpload(mediaId: created.id);
    final takenOverAt = DateTime.utc(2026, 5, 5);
    var asked = 0;

    await MediaUploadPipeline(
      mediaRepository: repo,
      queue: queue,
      // While the bytes transfer, another device moves the library to
      // store-b and its stamp syncs in.
      store: _SyncLandsDuringTransfer(
        () => repo.stampRemoteUploaded(
          created.id,
          uploadedAt: takenOverAt,
          storeId: 'store-b',
        ),
      ),
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: _FileResolver(file),
      }),
      cache: MediaCacheStore(database: cacheDb, root: root),
      storeId: 'store-a',
      takesOver: () async {
        asked++;
        return false;
      },
    ).process((await queue.nextPending(DateTime.now()))!);

    final after = (await repo.getMediaById(created.id))!;
    expect(asked, greaterThan(0), reason: 'asked again before stamping');
    expect(after.remoteStoreId, 'store-b');
    expect(
      after.remoteUploadedAt?.millisecondsSinceEpoch,
      takenOverAt.millisecondsSinceEpoch,
    );
  });

  // Copilot review: a stamp the takeover refuses must also stop the
  // namespace-switch cleanup after it, or the stale upload erases the
  // announced store's own rendition stamp.
  test(
    'a refused stamp leaves the announced store\'s rendition alone',
    () async {
      final file = File(p.join(root.path, 'switch.jpg'))
        ..writeAsBytesSync([5, 6, 7, 8]);
      final created = await repo.createMedia(
        MediaItem(
          id: '',
          mediaType: MediaType.photo,
          sourceType: MediaSourceType.localFile,
          filePath: file.path,
          localPath: file.path,
          originalFilename: 'switch.jpg',
          diveId: 'd1',
          takenAt: DateTime(2026),
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        ),
      );
      // This device's store held a rendition; it now re-uploads the original.
      await repo.stampRemoteCompressedUploaded(
        created.id,
        uploadedAt: DateTime.utc(2026),
        level: 'high',
        sizeBytes: 3,
        storeId: 'store-a',
      );
      await queue.enqueueReupload(
        mediaId: created.id,
        overrideLevel: 'original',
      );
      final takenOverAt = DateTime.utc(2026, 6, 6);
      var asked = 0;

      final outcome = await MediaUploadPipeline(
        mediaRepository: repo,
        queue: queue,
        // Mid-upload, another device moved the library to store-b and its
        // rendition stamp synced in.
        store: _SyncLandsDuringTransfer(
          () => repo.stampRemoteCompressedUploaded(
            created.id,
            uploadedAt: takenOverAt,
            level: 'small',
            sizeBytes: 2,
            storeId: 'store-b',
          ),
        ),
        registry: MediaSourceResolverRegistry({
          MediaSourceType.localFile: _FileResolver(file),
        }),
        cache: MediaCacheStore(database: cacheDb, root: root),
        storeId: 'store-a',
        takesOver: () async {
          asked++;
          return false;
        },
      ).process((await queue.nextPending(DateTime.now()))!);

      final after = (await repo.getMediaById(created.id))!;
      expect(asked, greaterThan(0), reason: 'asked before stamping');
      expect(outcome, UploadOutcome.leftToAnotherStore);
      expect(after.remoteStoreId, 'store-b');
      expect(
        after.remoteCompressedUploadedAt?.millisecondsSinceEpoch,
        takenOverAt.millisecondsSinceEpoch,
      );
      expect(after.remoteUploadedAt, isNull);
    },
  );

  // Review: asking which store the library announces is a database read,
  // and a throw escaping process() would strand the row in 'transferring'.
  test('a takeover check that throws fails the entry instead', () async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
        filePath: 'moved.jpg',
        localPath: 'moved.jpg',
        originalFilename: 'moved.jpg',
        diveId: 'd1',
        contentHash: 'h1',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.stampRemoteUploaded(
      created.id,
      uploadedAt: DateTime.utc(2026),
      storeId: 'store-b',
    );
    await queue.enqueueUpload(mediaId: created.id);

    final outcome = await MediaUploadPipeline(
      mediaRepository: repo,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: _FileResolver(File('unused')),
      }),
      cache: MediaCacheStore(database: cacheDb, root: root),
      storeId: 'store-a',
      takesOver: () async => throw StateError('database closed'),
    ).process((await queue.nextPending(DateTime.now()))!);

    expect(outcome, UploadOutcome.failed);
  });

  // Review: a video's transcode is kept only for a retry, and a row left to
  // another store gets none, so the transcode goes with the entry.
  test('a video left to another store drops its transcode', () async {
    final created = await repo.createMedia(
      MediaItem(
        id: '',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.localFile,
        filePath: 'moved.mov',
        localPath: 'moved.mov',
        originalFilename: 'moved.mov',
        diveId: 'd1',
        contentHash: 'hv',
        takenAt: DateTime(2026),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      ),
    );
    await repo.stampRemoteUploaded(
      created.id,
      uploadedAt: DateTime.utc(2026),
      storeId: 'store-b',
    );
    await queue.enqueueUpload(mediaId: created.id);
    final cache = MediaCacheStore(database: cacheDb, root: root);
    final transcode = await cache.transcodeFile('hv', 'high');
    await transcode.writeAsBytes([1, 2, 3]);

    final outcome = await MediaUploadPipeline(
      mediaRepository: repo,
      queue: queue,
      store: InMemoryMediaObjectStore(),
      registry: MediaSourceResolverRegistry({
        MediaSourceType.localFile: _FileResolver(transcode),
      }),
      cache: cache,
      storeId: 'store-a',
      takesOver: () async => false,
    ).process((await queue.nextPending(DateTime.now()))!);

    expect(outcome, UploadOutcome.leftToAnotherStore);
    expect(transcode.existsSync(), isFalse);
  });
}
