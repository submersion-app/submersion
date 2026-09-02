import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository mediaRepository;
  late SiteRepository siteRepository;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    mediaRepository = MediaRepository();
    siteRepository = SiteRepository(
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

  final epoch = DateTime(2026, 1, 1).millisecondsSinceEpoch;

  Future<void> insertDive(String id) => db
      .into(db.dives)
      .insert(
        DivesCompanion(
          id: Value(id),
          diveDateTime: Value(epoch),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  Future<void> insertSite(String id) => db
      .into(db.diveSites)
      .insert(
        DiveSitesCompanion(
          id: Value(id),
          name: const Value('Reef'),
          createdAt: Value(epoch),
          updatedAt: Value(epoch),
        ),
      );

  MediaItem item(
    String name, {
    String? diveId,
    String? siteId,
    String? hash,
    DateTime? uploadedAt,
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
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
    final rows = await (db.select(
      db.deletionLog,
    )..where((t) => t.entityType.equals('media'))).get();
    return rows.map((r) => r.recordId).toList();
  }

  group('partitionMediaForSiteDeletion', () {
    test('site-only media is doomed; dive-linked rows unlink', () async {
      await insertSite('s1');
      await insertDive('d1');
      final siteOnly = await mediaRepository.createMedia(
        item('a.pdf', siteId: 's1', mediaType: MediaType.document),
      );
      final diveLinked = await mediaRepository.createMedia(
        item('b.jpg', siteId: 's1', diveId: 'd1'),
      );
      // A URL row is site-only too: no source type is exempt from the
      // cascade, so it dies with the site like the document does.
      final urlRow = await mediaRepository.createMedia(
        item('c.jpg', siteId: 's1', sourceType: MediaSourceType.networkUrl),
      );
      await mediaRepository.createMedia(
        item('other.jpg', diveId: 'd1'),
      ); // unrelated

      final split = await mediaRepository.partitionMediaForSiteDeletion(['s1']);
      expect(split.doomed.map((m) => m.id).toSet(), {siteOnly.id, urlRow.id});
      expect(split.unlinkIds, [diveLinked.id]);
    });

    test('empty input returns empty partition', () async {
      await insertSite('s1');
      await mediaRepository.createMedia(item('a.jpg', siteId: 's1'));

      final split = await mediaRepository.partitionMediaForSiteDeletion([]);
      expect(split.doomed, isEmpty);
      expect(split.unlinkIds, isEmpty);
    });
  });

  group('unlinkMediaFromDeletedSites', () {
    test('nulls siteId, keeps the row, and marks sync-pending', () async {
      await insertSite('s1');
      final m = await mediaRepository.createMedia(item('a.jpg', siteId: 's1'));

      await mediaRepository.unlinkMediaFromDeletedSites([m.id]);

      final got = await mediaRepository.getMediaById(m.id);
      expect(got, isNotNull);
      expect(got!.siteId, isNull);
      final pending = await (db.select(
        db.syncRecords,
      )..where((t) => t.recordId.equals(m.id))).get();
      expect(pending.map((r) => r.syncStatus), contains('pending'));
    });
  });

  group('SiteRepository.deleteSite cascade', () {
    test('site-only media dies with tombstone and blob intent', () async {
      await insertSite('s1');
      final doomed = await mediaRepository.createMedia(
        item(
          'map.pdf',
          siteId: 's1',
          mediaType: MediaType.document,
          hash: 'h1',
          uploadedAt: DateTime(2026, 2),
        ),
      );

      await siteRepository.deleteSite('s1');

      expect(await mediaRepository.getMediaById(doomed.id), isNull);
      expect(await mediaTombstones(), contains(doomed.id));
      final entry = (await queue.allForTesting()).single;
      expect(entry.direction, 'delete');
      expect(entry.contentHash, 'h1');
      final sites = await db.select(db.diveSites).get();
      expect(sites, isEmpty);
    });

    test('dive-linked media survives with siteId nulled', () async {
      await insertSite('s1');
      await insertDive('d1');
      final kept = await mediaRepository.createMedia(
        item('b.jpg', siteId: 's1', diveId: 'd1'),
      );

      await siteRepository.deleteSite('s1');

      final got = await mediaRepository.getMediaById(kept.id);
      expect(got, isNotNull);
      expect(got!.siteId, isNull);
      expect(got.diveId, 'd1');
      expect(await queue.allForTesting(), isEmpty);
    });

    test('bulkDeleteSites cascades across all deleted sites', () async {
      await insertSite('s1');
      await insertSite('s2');
      final m1 = await mediaRepository.createMedia(item('a.jpg', siteId: 's1'));
      final m2 = await mediaRepository.createMedia(item('b.jpg', siteId: 's2'));

      await siteRepository.bulkDeleteSites(['s1', 's2']);

      expect(await mediaRepository.getMediaById(m1.id), isNull);
      expect(await mediaRepository.getMediaById(m2.id), isNull);
      expect(await mediaTombstones(), containsAll([m1.id, m2.id]));
    });

    test('cascadeMedia false leaves media untouched', () async {
      await insertSite('s1');
      final m = await mediaRepository.createMedia(item('a.jpg', siteId: 's1'));

      await siteRepository.deleteSite('s1', cascadeMedia: false);

      // The row survives; the FK SET NULL clears siteId at the SQL level.
      expect(await mediaRepository.getMediaById(m.id), isNotNull);
    });
  });
}
