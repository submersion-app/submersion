import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository mediaRepository;
  late DiveRepository diveRepository;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    mediaRepository = MediaRepository();
    diveRepository = DiveRepository(
      mediaRepository: mediaRepository,
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: mediaRepository,
        queue: () => queue,
      ),
    );
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  Future<Dive> makeDive() =>
      diveRepository.createDive(Dive(id: '', dateTime: DateTime(2026, 6, 1)));

  Future<String> insertSite() async {
    final db = DatabaseService.instance.database;
    final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;
    await db
        .into(db.diveSites)
        .insert(
          DiveSitesCompanion(
            id: const Value('site-1'),
            name: const Value('Reef'),
            createdAt: Value(epoch),
            updatedAt: Value(epoch),
          ),
        );
    return 'site-1';
  }

  MediaItem item(
    String name, {
    String? diveId,
    String? siteId,
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
    siteId: siteId,
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
    takenAt: DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  Future<List<String>> mediaTombstones() async {
    final db = DatabaseService.instance.database;
    final rows = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('media'))).get();
    return rows.map((r) => r.recordId).toList();
  }

  test('deleteDive deletes dive-only media with tombstone and blob intent',
      () async {
    final dive = await makeDive();
    final doomed = await mediaRepository.createMedia(
      item(
        'a.jpg',
        diveId: dive.id,
        hash: 'h1',
        uploadedAt: DateTime(2026, 2),
      ),
    );

    await diveRepository.deleteDive(dive.id);

    expect(await mediaRepository.getMediaById(doomed.id), isNull);
    expect(await mediaTombstones(), contains(doomed.id));
    final entry = (await queue.allForTesting()).single;
    expect(entry.direction, 'delete');
    expect(entry.contentHash, 'h1');
  });

  test('site-linked media survives with diveId nulled', () async {
    final dive = await makeDive();
    final site = await insertSite();
    final kept = await mediaRepository.createMedia(
      item('b.jpg', diveId: dive.id, siteId: site),
    );

    await diveRepository.deleteDive(dive.id);

    final got = await mediaRepository.getMediaById(kept.id);
    expect(got, isNotNull);
    expect(got!.diveId, isNull);
    expect(got.siteId, site);
    expect(await queue.allForTesting(), isEmpty);
  });

  test('library-level media reverts to library instead of dying', () async {
    final dive = await makeDive();
    final kept = await mediaRepository.createMedia(
      item(
        'c.jpg',
        diveId: dive.id,
        sourceType: MediaSourceType.networkUrl,
      ),
    );

    await diveRepository.deleteDive(dive.id);

    final got = await mediaRepository.getMediaById(kept.id);
    expect(got, isNotNull);
    expect(got!.diveId, isNull);
    expect(await queue.allForTesting(), isEmpty);
  });

  test('bulkDeleteDives cascades across all deleted dives', () async {
    final d1 = await makeDive();
    final d2 = await makeDive();
    final m1 = await mediaRepository.createMedia(
      item('a.jpg', diveId: d1.id, hash: 'h1', uploadedAt: DateTime(2026, 2)),
    );
    final m2 = await mediaRepository.createMedia(
      item('b.jpg', diveId: d2.id, hash: 'h2', uploadedAt: DateTime(2026, 2)),
    );

    await diveRepository.bulkDeleteDives([d1.id, d2.id]);

    expect(await mediaRepository.getMediaById(m1.id), isNull);
    expect(await mediaRepository.getMediaById(m2.id), isNull);
    expect(await mediaTombstones(), containsAll([m1.id, m2.id]));
    final hashes = (await queue.allForTesting())
        .map((e) => e.contentHash)
        .toSet();
    expect(hashes, {'h1', 'h2'});
  });

  test('never-uploaded dive-only media dies without a blob intent',
      () async {
    final dive = await makeDive();
    final doomed = await mediaRepository.createMedia(
      item('plain.jpg', diveId: dive.id),
    );

    await diveRepository.deleteDive(dive.id);

    expect(await mediaRepository.getMediaById(doomed.id), isNull);
    expect(await mediaTombstones(), contains(doomed.id));
    expect(await queue.allForTesting(), isEmpty);
  });
}
