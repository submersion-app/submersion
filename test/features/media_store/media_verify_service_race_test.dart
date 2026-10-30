import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/app_sql_functions.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/media_store/media_object_store.dart';
import 'package:submersion/core/services/media_store/store_keys.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';
import 'package:submersion/features/media_store/data/media_verify_service.dart';

import '../../helpers/in_memory_media_object_store.dart';
import '../../helpers/test_database.dart';

/// Runs [afterListing] once the sweep has read the whole listing, before it
/// classifies and deletes anything: the moment a row can start using an
/// object the sweep already judged.
class _AfterListingStore extends InMemoryMediaObjectStore {
  Future<void> Function()? afterListing;

  @override
  Stream<StoreObjectInfo> list(String keyPrefix) async* {
    yield* super.list(keyPrefix);
    await afterListing?.call();
  }
}

/// The sweep judges every key against references it read at its start. A
/// row that starts using an object while the sweep runs (an import whose
/// upload finds the object already there, a quality switch rewriting a
/// key) must not lose that object to the stale judgment.
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository repo;
  late _AfterListingStore store;
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
    store = _AfterListingStore();
    service = MediaVerifyService(
      store: store,
      mediaRepository: repo,
      queue: queue,
      now: () => now,
    );
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

  /// A photo row with [hash], stamped as uploaded.
  Future<void> stampedPhoto(String name, String hash) async {
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
    await repo.stampRemoteUploaded(created.id, uploadedAt: DateTime(2026, 2));
  }

  void seedObject(String key) {
    store.objects[key] = [1, 2, 3];
    store.modified[key] = old;
  }

  test('an orphan a row starts using mid-sweep is not deleted', () async {
    // An import whose upload finds the old orphan already there stamps its
    // new row and uploads nothing; deleting the object then leaves that
    // row backed up by nothing.
    await stampedPhoto('kept.jpg', 'aabb');
    seedObject(StoreKeys.objectKey('aabb', extension: 'jpg'));
    final orphan = StoreKeys.objectKey('ccdd', extension: 'jpg');
    seedObject(orphan);
    store.afterListing = () => stampedPhoto('again.jpg', 'ccdd');

    final report = await service.run();

    expect(store.objects.keys, contains(orphan));
    expect(report.orphansRemoved, 0);
  });

  test('a sibling whose rows changed mid-sweep is kept', () async {
    // A quality switch that rewrites a rendition key the sweep judged an
    // unused sibling: the row now needs it.
    await stampedPhoto('kept.jpg', 'aabb');
    seedObject(StoreKeys.objectKey('aabb', extension: 'jpg'));
    final sibling = StoreKeys.objectKey('aabb', extension: 'jpeg');
    seedObject(sibling);
    store.afterListing = () => stampedPhoto('kept.jpeg', 'aabb');

    await service.run();

    expect(store.objects.keys, contains(sibling));
  });

  test('an orphan nothing started using is still deleted', () async {
    await stampedPhoto('kept.jpg', 'aabb');
    seedObject(StoreKeys.objectKey('aabb', extension: 'jpg'));
    final orphan = StoreKeys.objectKey('ccdd', extension: 'jpg');
    seedObject(orphan);

    final report = await service.run();

    expect(store.objects.keys, isNot(contains(orphan)));
    expect(report.orphansRemoved, 1);
  });
}
