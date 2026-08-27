import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repair_log_repository.dart';
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
  late MediaRepairLogRepository logRepo;
  late MediaRepairService service;
  late Directory root;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    repo = MediaRepository();
    logRepo = MediaRepairLogRepository();
    service = MediaRepairService(
      repository: repo,
      queue: MediaTransferQueueRepository(database: cacheDb),
      createBookmark: null,
      writeBookmark: null,
      log: logRepo,
    );
    root = await Directory.systemTemp.createTemp('repair-log-test');
  });

  tearDown(() async {
    await cacheDb.close();
    await root.delete(recursive: true);
    await tearDownTestDatabase();
  });

  Future<MediaItem> seed(
    String id, {
    String? contentHash,
    bool stampRemote = false,
  }) async {
    final created = await repo.createMedia(
      MediaItem(
        id: id,
        mediaType: MediaType.photo,
        sourceType: MediaSourceType.localFile,
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

  test(
    'an applied relink writes one audit row with old and new pointers',
    () async {
      final (file, hash) = await tempFile('a.jpg', 'aaaa');
      await seed('a', contentHash: hash);
      final item = (await repo.getMediaById('a'))!;

      await service.apply([
        RepairProposal(
          item: item,
          confidence: RepairConfidence.exact,
          candidate: RepairCandidate.file(path: file.path, sizeBytes: 4),
        ),
      ], source: RepairLogSource.watcher);

      final entries = await logRepo.recent();
      expect(entries, hasLength(1));
      expect(entries.single.mediaId, 'a');
      // The watcher's applies are auto-repairs, not user-driven relinks.
      expect(entries.single.action, RepairLogAction.autoRelink);
      expect(entries.single.oldValue, '/gone/a.jpg');
      expect(entries.single.newValue, file.path);
      expect(entries.single.source, RepairLogSource.watcher);
    },
  );

  test('a manual source records the plain relink action', () async {
    final (file, hash) = await tempFile('a.jpg', 'aaaa');
    await seed('a', contentHash: hash);
    final item = (await repo.getMediaById('a'))!;

    await service.apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: file.path, sizeBytes: 4),
      ),
    ], source: RepairLogSource.folder);

    expect((await logRepo.recent()).single.action, RepairLogAction.relink);
  });

  test('a cloud-backed conversion logs the cloudBacked action', () async {
    await seed('a', contentHash: 'H1', stampRemote: true);
    final item = (await repo.getMediaById('a'))!;

    await service.apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.exact,
        candidate: const RepairCandidate.store(verified: true),
      ),
    ], source: RepairLogSource.store);

    final entry = (await logRepo.recent()).single;
    expect(entry.action, RepairLogAction.cloudBacked);
    expect(entry.source, RepairLogSource.store);
  });

  test('every row from one apply shares a batch id', () async {
    final (fileA, hashA) = await tempFile('a.jpg', 'aaaa');
    final (fileB, hashB) = await tempFile('b.jpg', 'bbbb');
    await seed('a', contentHash: hashA);
    await seed('b', contentHash: hashB);

    await service.apply([
      RepairProposal(
        item: (await repo.getMediaById('a'))!,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: fileA.path, sizeBytes: 4),
      ),
      RepairProposal(
        item: (await repo.getMediaById('b'))!,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: fileB.path, sizeBytes: 4),
      ),
    ]);

    final entries = await logRepo.recent();
    expect(entries, hasLength(2));
    expect(entries.map((e) => e.batchId).toSet(), hasLength(1));
  });

  test('record prunes to the newest 500 rows', () async {
    await logRepo.record([
      for (var i = 0; i < 505; i++)
        RepairLogEntry(
          id: 'e$i',
          mediaId: 'm$i',
          batchId: 'b',
          occurredAt: DateTime.fromMillisecondsSinceEpoch(i),
          action: RepairLogAction.relink,
          source: RepairLogSource.manual,
        ),
    ]);

    final entries = await logRepo.recent(limit: 1000);
    expect(entries, hasLength(500));
    // Newest survive: the five oldest (e0..e4) are gone.
    expect(entries.map((e) => e.id), isNot(contains('e0')));
    expect(entries.first.id, 'e504');
  });

  test('a failing audit write does not fail the applied repair', () async {
    final (file, hash) = await tempFile('a.jpg', 'aaaa');
    await seed('a', contentHash: hash);
    final item = (await repo.getMediaById('a'))!;

    final failing = MediaRepairService(
      repository: repo,
      queue: MediaTransferQueueRepository(database: cacheDb),
      createBookmark: null,
      writeBookmark: null,
      log: _ThrowingLogRepository(),
    );

    // The repair is already committed by the time history is written, so
    // letting a log failure escape would report success as failure and
    // invite a retry against rows that are no longer missing.
    final report = await failing.apply([
      RepairProposal(
        item: item,
        confidence: RepairConfidence.exact,
        candidate: RepairCandidate.file(path: file.path, sizeBytes: 4),
      ),
    ], source: RepairLogSource.watcher);

    expect(report.relinked, 1);
    expect(report.failed, 0);
    final repaired = (await repo.getMediaById('a'))!;
    expect(repaired.localPath, file.path);
    expect(repaired.isOrphaned, isFalse);
  });
}

class _ThrowingLogRepository implements MediaRepairLogRepository {
  @override
  Future<void> record(List<RepairLogEntry> entries) async =>
      throw StateError('no such table: media_repair_log');

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
