import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart' hide Dive;
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/features/dive_import/data/repositories/imported_file_repository.dart';
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
  late ImportedFileRepository importedFiles;

  setUp(() async {
    await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    mediaRepository = MediaRepository();
    importedFiles = ImportedFileRepository();
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

  test(
    'deleteDive deletes dive-only media with tombstone and blob intent',
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
    },
  );

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

  test('network media dies with its dive like any other photo', () async {
    // No source type is exempt from the cascade: a row with no dive and no
    // site has no place in the library, so a URL row that only this dive
    // owned goes with it. It was never uploaded, so no blob intent either.
    final dive = await makeDive();
    final doomed = await mediaRepository.createMedia(
      item('c.jpg', diveId: dive.id, sourceType: MediaSourceType.networkUrl),
    );

    await diveRepository.deleteDive(dive.id);

    expect(await mediaRepository.getMediaById(doomed.id), isNull);
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

  test('never-uploaded dive-only media dies without a blob intent', () async {
    final dive = await makeDive();
    final doomed = await mediaRepository.createMedia(
      item('plain.jpg', diveId: dive.id),
    );

    await diveRepository.deleteDive(dive.id);

    expect(await mediaRepository.getMediaById(doomed.id), isNull);
    expect(await mediaTombstones(), contains(doomed.id));
    expect(await queue.allForTesting(), isEmpty);
  });

  group('imported file cascade (issue #478)', () {
    Future<bool> stillStored(String id) => importedFiles.exists(id);

    Future<String> storeFileFor(
      List<String> diveIds, {
      List<int> bytes = const [1, 2, 3],
    }) async {
      final db = DatabaseService.instance.database;
      final id = await importedFiles.store(
        bytes: Uint8List.fromList(bytes),
        fileName: 'logbook.uddf',
      );
      for (final diveId in diveIds) {
        await db
            .into(db.diveDataSources)
            .insert(
              DiveDataSourcesCompanion.insert(
                id: 'src-$diveId',
                diveId: diveId,
                isPrimary: const Value(true),
                importedAt: DateTime(2026, 1, 1),
                createdAt: DateTime(2026, 1, 1),
                sourceFileFormat: const Value('uddf'),
                importedFileId: Value(id),
              ),
            );
      }
      return id;
    }

    test('deleting the only dive that points at a stored file removes '
        'it', () async {
      final dive = await makeDive();
      final id = await storeFileFor([dive.id]);

      await diveRepository.deleteDive(dive.id);

      expect(await stillStored(id), isFalse);
    });

    test('a file shared by a surviving dive is kept', () async {
      final d1 = await makeDive();
      final d2 = await makeDive();
      final id = await storeFileFor([d1.id, d2.id]);

      await diveRepository.deleteDive(d1.id);

      expect(await stillStored(id), isTrue);

      await diveRepository.deleteDive(d2.id);

      expect(await stillStored(id), isFalse);
    });

    test('bulkDeleteDives removes a file once its last pointer goes', () async {
      final d1 = await makeDive();
      final d2 = await makeDive();
      final d3 = await makeDive();
      final shared = await storeFileFor([d1.id, d2.id]);
      final other = await storeFileFor([d3.id], bytes: const [9, 9, 9]);

      await diveRepository.bulkDeleteDives([d1.id, d2.id]);

      expect(await stillStored(shared), isFalse);
      expect(await stillStored(other), isTrue);
    });

    test('tombstones the reclaimed row so peers drop it too', () async {
      final dive = await makeDive();
      final id = await storeFileFor([dive.id]);
      final db = DatabaseService.instance.database;

      await diveRepository.deleteDive(dive.id);

      final tombstones = await (db.select(
        db.deletionLog,
      )..where((t) => t.entityType.equals('importedFiles'))).get();
      expect(tombstones.map((r) => r.recordId), contains(id));
    });

    test('sweeps a row an earlier run orphaned as well', () async {
      // The sweep asks which rows nothing names any more, so it also collects
      // a row left behind by an import that never wrote its source row -- the
      // garbage the on-disk folder had no way to reclaim at all.
      final dive = await makeDive();
      final id = await storeFileFor([dive.id]);
      final stray = await importedFiles.store(
        bytes: Uint8List.fromList(const [7, 7, 7, 7]),
        fileName: 'never-referenced.uddf',
      );

      await diveRepository.deleteDive(dive.id);

      expect(await stillStored(id), isFalse);
      expect(await stillStored(stray), isFalse);
    });

    test(
      'a restore-safe delete (cascadeMedia: false) keeps the file',
      () async {
        final dive = await makeDive();
        final id = await storeFileFor([dive.id]);

        await diveRepository.deleteDive(dive.id, cascadeMedia: false);

        expect(await stillStored(id), isTrue);
      },
    );
  });
}
