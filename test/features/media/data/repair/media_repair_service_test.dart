import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/services/repair/media_repair_service.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media/domain/services/media_repair_types.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaRepository repo;
  late MediaTransferQueueRepository queue;
  late Directory root;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaRepository();
    queue = MediaTransferQueueRepository(database: cacheDb);
    root = await Directory.systemTemp.createTemp('repair-service-test');
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  MediaRepairService service({
    Future<Uint8List> Function(String path)? createBookmark,
    Future<void> Function(String ref, Uint8List blob)? writeBookmark,
  }) => MediaRepairService(
    repository: repo,
    queue: queue,
    createBookmark: createBookmark,
    writeBookmark: writeBookmark,
  );

  Future<MediaItem> seed(
    String id, {
    String? contentHash,
    bool stampRemote = false,
    MediaSourceType sourceType = MediaSourceType.localFile,
    String? platformAssetId,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: id,
        mediaType: MediaType.photo,
        sourceType: sourceType,
        platformAssetId: platformAssetId,
        filePath: '/gone/$id.jpg',
        localPath: '/gone/$id.jpg',
        originalFilename: '$id.jpg',
        isOrphaned: true,
        takenAt: DateTime(2026, 6, 1),
        createdAt: DateTime(2026, 6, 1),
        updatedAt: DateTime(2026, 6, 1),
      ),
    );
    if (contentHash != null) {
      await repo.stampContentIdentity(
        id,
        contentHash: contentHash,
        sizeBytes: 4,
      );
    }
    if (stampRemote) {
      await db.customStatement(
        'UPDATE media SET remote_uploaded_at = 123 WHERE id = ?',
        [id],
      );
    }
    return created;
  }

  Future<(File, String)> tempFile(String name, String contents) async {
    final file = File('${root.path}/$name');
    await file.writeAsString(contents);
    final digest = await sha256OfFile(file);
    return (file, digest.hash);
  }

  test('exact file proposal rewrites the path and clears isOrphaned', () async {
    final (file, hash) = await tempFile('a.jpg', 'aaaa');
    await seed('a', contentHash: hash);
    final item = (await repo.getMediaById('a'))!;

    final report = await service().apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: file.path, sizeBytes: 4),
      ),
    ]);

    expect(report.relinked, 1);
    final repaired = (await repo.getMediaById('a'))!;
    expect(repaired.localPath, file.path);
    expect(repaired.isOrphaned, isFalse);
    expect(repaired.lastVerifiedAt, isNotNull);
  });

  test(
    'probable proposal whose bytes differ is skipped as changed-on-disk',
    () async {
      final (file, _) = await tempFile('a.jpg', 'DIFFERENT');
      await seed('a', contentHash: 'ORIGINAL-HASH');
      final item = (await repo.getMediaById('a'))!;

      final report = await service().apply([
        RepairProposal(
          item: item,
          confidence: RepairConfidence.probable,
          candidate: RepairCandidate.file(path: file.path, sizeBytes: 9),
        ),
      ]);

      expect(report.skipped, 1);
      expect(report.relinked, 0);
      final untouched = (await repo.getMediaById('a'))!;
      expect(untouched.localPath, '/gone/a.jpg');
      expect(untouched.isOrphaned, isTrue);
    },
  );

  test('edited acceptance re-stamps identity, clears remote stamps, and '
      'enqueues an upload', () async {
    final (file, newHash) = await tempFile('a.jpg', 'NEW BYTES');
    await seed('a', contentHash: 'OLD-HASH', stampRemote: true);
    final item = (await repo.getMediaById('a'))!;

    final report = await service().apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.edited,
        candidate: RepairCandidate.file(path: file.path, sizeBytes: 9),
      ),
    ]);

    expect(report.relinked, 1);
    expect(report.reuploadsQueued, 1);
    final repaired = (await repo.getMediaById('a'))!;
    expect(repaired.localPath, file.path);
    expect(repaired.contentHash, newHash);
    expect(repaired.remoteUploadedAt, isNull);

    final queued = await cacheDb
        .customSelect(
          "SELECT media_id FROM media_transfer_queue "
          "WHERE direction = 'upload'",
        )
        .get();
    expect(queued.map((r) => r.read<String>('media_id')), contains('a'));
  });

  test('store proposal converts to cloud-backed', () async {
    await seed('a', contentHash: 'H1', stampRemote: true);
    final item = (await repo.getMediaById('a'))!;

    final report = await service().apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.exact,
        candidate: const RepairCandidate.store(verified: true),
      ),
    ]);

    expect(report.cloudBacked, 1);
    final repaired = (await repo.getMediaById('a'))!;
    expect(repaired.sourceType, MediaSourceType.mediaStore);
    expect(repaired.localPath, isNull);
  });

  test('gallery proposal flips the row to platformGallery', () async {
    await seed('a');
    final item = (await repo.getMediaById('a'))!;

    final report = await service().apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.probable,
        candidate: const RepairCandidate.galleryAsset(
          assetId: 'asset-9',
          sizeBytes: null,
        ),
      ),
    ]);

    expect(report.relinked, 1);
    final repaired = (await repo.getMediaById('a'))!;
    expect(repaired.sourceType, MediaSourceType.platformGallery);
    expect(repaired.platformAssetId, 'asset-9');
    expect(repaired.isOrphaned, isFalse);
  });

  test('file proposal on a gallery row retargets it to localFile', () async {
    // A photo deleted from the device library but restored to disk: the row
    // must stop routing through PlatformGalleryResolver, or lifting the
    // orphan flag would only hide the breakage.
    final (file, hash) = await tempFile('a.jpg', 'aaaa');
    await seed(
      'a',
      contentHash: hash,
      sourceType: MediaSourceType.platformGallery,
      platformAssetId: 'dead-asset',
    );
    final item = (await repo.getMediaById('a'))!;

    final report = await service().apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: file.path, sizeBytes: 4),
      ),
    ]);

    expect(report.relinked, 1);
    final repaired = (await repo.getMediaById('a'))!;
    expect(repaired.sourceType, MediaSourceType.localFile);
    expect(repaired.platformAssetId, isNull);
    expect(repaired.localPath, file.path);
    expect(repaired.isOrphaned, isFalse);
  });

  test('bookmark failure fails that row only', () async {
    final (fileA, hashA) = await tempFile('a.jpg', 'aaaa');
    final (fileB, hashB) = await tempFile('b.jpg', 'bbbb');
    await seed('a', contentHash: hashA);
    await seed('b', contentHash: hashB);
    final itemA = (await repo.getMediaById('a'))!;
    final itemB = (await repo.getMediaById('b'))!;

    final report =
        await service(
          createBookmark: (path) async {
            if (path == fileA.path) throw Exception('sandbox denied');
            return Uint8List.fromList([1, 2, 3]);
          },
          writeBookmark: (ref, blob) async {},
        ).apply([
          RepairProposal(
            item: itemA,
            confidence: RepairConfidence.exact,
            candidate: RepairCandidate.file(path: fileA.path, sizeBytes: 4),
          ),
          RepairProposal(
            item: itemB,
            confidence: RepairConfidence.exact,
            candidate: RepairCandidate.file(path: fileB.path, sizeBytes: 4),
          ),
        ]);

    expect(report.failed, 1);
    expect(report.relinked, 1);
    expect((await repo.getMediaById('a'))!.localPath, '/gone/a.jpg');
    expect((await repo.getMediaById('b'))!.localPath, fileB.path);
    expect((await repo.getMediaById('b'))!.bookmarkRef, isNotNull);
  });
}
