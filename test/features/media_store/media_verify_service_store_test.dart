// Issue #3482: Verify's reverse repair clears a stamp whose object the
// attached store lacks. A stamp made in another store says nothing about
// this one, so it is left alone; clearing it would wipe the other store's
// synced record for every device still using it.

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository repo;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(
      NativeDatabase.memory(setup: registerAppSqlFunctions),
    );
    queue = MediaTransferQueueRepository(database: cacheDb);
    repo = MediaRepository();
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
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<String> stamped(String name, String hash, String? storeId) async {
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
    await repo.stampRemoteUploaded(
      created.id,
      uploadedAt: DateTime(2026, 2),
      storeId: storeId,
    );
    return created.id;
  }

  MediaVerifyService verifier() => MediaVerifyService(
    store: InMemoryMediaObjectStore(),
    mediaRepository: repo,
    queue: queue,
    storeId: 'store-b',
    now: () => DateTime(2026, 3),
  );

  test('another store\'s stamps are left alone', () async {
    final elsewhere = await stamped('a.jpg', 'aa11', 'store-a');

    final report = await verifier().run();

    expect((await repo.getMediaById(elsewhere))!.remoteUploadedAt, isNotNull);
    expect((await repo.getMediaById(elsewhere))!.remoteStoreId, 'store-a');
    expect(report.repairsQueued, 0);
  });

  test('this store\'s and unclaimed stale stamps are still repaired', () async {
    final here = await stamped('b.jpg', 'bb22', 'store-b');
    final legacy = await stamped('c.jpg', 'cc33', null);

    final report = await verifier().run();

    expect((await repo.getMediaById(here))!.remoteUploadedAt, isNull);
    expect((await repo.getMediaById(legacy))!.remoteUploadedAt, isNull);
    expect(report.repairsQueued, 2);
  });
}
