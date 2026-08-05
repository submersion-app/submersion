import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
    SharedPreferences.setMockInitialValues({});
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
      prefs: SharedPreferences.getInstance,
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

  test('sweeps old unlinked non-library rows exactly once', () async {
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
    final library = await repo.createMedia(
      item('lib.jpg', sourceType: MediaSourceType.networkUrl),
    );
    final linked = await repo.createMedia(item('linked.jpg', diveId: 'd1'));

    final swept = await sweep.runIfNeeded(now: sweepTime);
    expect(swept, 1);
    expect(await repo.getMediaById(orphan.id), isNull);
    expect(await repo.getMediaById(library.id), isNotNull);
    expect(await repo.getMediaById(linked.id), isNotNull);
    // The uploaded orphan produced a blob-delete intent.
    final entry = (await queue.allForTesting()).single;
    expect(entry.direction, 'delete');
    expect(entry.contentHash, 'h1');

    // Second run is a no-op: the flag persisted.
    await repo.createMedia(item('later-orphan.jpg'));
    expect(await sweep.runIfNeeded(now: sweepTime), 0);
  });

  test(
    'flag stays unset when the sweep fails, so it retries next launch',
    () async {
      final broken = MediaOrphanBacklogSweep(
        mediaRepository: _ThrowingMediaRepository(),
        coordinator: MediaDeletionCoordinator(
          mediaRepository: repo,
          queue: () => queue,
        ),
        prefs: SharedPreferences.getInstance,
      );
      await expectLater(broken.runIfNeeded(now: sweepTime), throwsStateError);
      final p = await SharedPreferences.getInstance();
      expect(p.getBool(MediaOrphanBacklogSweep.flagKey), isNot(true));
      // The healthy sweep still runs afterwards.
      expect(await sweep.runIfNeeded(now: sweepTime), 0);
      expect(p.getBool(MediaOrphanBacklogSweep.flagKey), isTrue);
    },
  );
}
