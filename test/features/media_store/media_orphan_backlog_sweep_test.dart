import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_orphan_backlog_sweep.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../helpers/test_database.dart';

class _ThrowingMediaRepository extends MediaRepository {
  @override
  Future<List<String>> getSweepableOrphanIds({required DateTime olderThan}) {
    throw StateError('db unavailable');
  }
}

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository repo;
  late MediaOrphanBacklogSweep sweep;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    repo = MediaRepository();
    sweep = MediaOrphanBacklogSweep(
      mediaRepository: repo,
      coordinator: MediaDeletionCoordinator(
        mediaRepository: repo,
        queue: () => queue,
      ),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  MediaItem item(
    String name, {
    String? diveId,
    String? hash,
    DateTime? uploadedAt,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
  }) => MediaItem(
    id: '',
    mediaType: MediaType.photo,
    sourceType: sourceType,
    filePath: '/tmp/$name',
    localPath: '/tmp/$name',
    originalFilename: name,
    diveId: diveId,
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  // createMedia stamps createdAt with the real wall clock, so the sweep's
  // 24h age guard is satisfied by running "two days in the future".
  final sweepTime = DateTime.now().add(const Duration(days: 2));

  test('sweeps every old unlinked row on each run', () async {
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
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
    final orphan = await repo.createMedia(
      item('orphan.jpg', hash: 'h1', uploadedAt: DateTime(2026, 2)),
    );
    final url = await repo.createMedia(
      item('url.jpg', sourceType: MediaSourceType.networkUrl),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    expect(await sweep.run(now: sweepTime), 2);
    expect(await repo.getMediaById(orphan.id), isNull);
    expect(await repo.getMediaById(url.id), isNull);
    expect(await repo.getMediaById(linked.id), isNotNull);
    // The uploaded orphan produced a blob-delete intent.
    final entry = (await queue.allForTesting()).single;
    expect(entry.direction, 'delete');
    expect(entry.contentHash, 'h1');

    // A second run is idempotent on a clean library.
    expect(await sweep.run(now: sweepTime), 0);

    // A row that arrives later (a peer that has not upgraded yet can still
    // sync one in) is caught on a later launch once it is old enough.
    final late = await repo.createMedia(item('late-orphan.jpg'));
    expect(await sweep.run(now: sweepTime), 1);
    expect(await repo.getMediaById(late.id), isNull);
  });

  test('a row younger than the age guard is left alone', () async {
    await repo.createMedia(item('fresh.jpg'));
    expect(await sweep.run(now: DateTime.now()), 0);
  });

  test('a repository failure propagates', () async {
    final broken = MediaOrphanBacklogSweep(
      mediaRepository: _ThrowingMediaRepository(),
      coordinator: MediaDeletionCoordinator(
        mediaRepository: repo,
        queue: () => queue,
      ),
    );
    await expectLater(broken.run(now: sweepTime), throwsStateError);
  });
}
