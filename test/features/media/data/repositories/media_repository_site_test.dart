import 'package:drift/drift.dart' show Value;
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/test_database.dart';

void main() {
  late AppDatabase db;
  late MediaRepository repository;

  setUp(() async {
    db = await setUpTestDatabase();
    repository = MediaRepository();
  });
  tearDown(tearDownTestDatabase);

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
    String? platformAssetId,
    String? localPath,
    MediaType mediaType = MediaType.photo,
    MediaSourceType sourceType = MediaSourceType.platformGallery,
    DateTime? takenAt,
  }) => MediaItem(
    id: '',
    mediaType: mediaType,
    sourceType: sourceType,
    platformAssetId: platformAssetId,
    filePath: '/tmp/$name',
    localPath: localPath,
    originalFilename: name,
    diveId: diveId,
    siteId: siteId,
    takenAt: takenAt ?? DateTime(2026, 1, 1),
    createdAt: DateTime(2026, 1, 1),
    updatedAt: DateTime(2026, 1, 1),
  );

  group('getMediaForSite', () {
    test('returns only media linked to the site, ordered by takenAt', () async {
      await insertSite('site-1');
      await insertDive('dive-1');

      final late1 = await repository.createMedia(
        item('late.jpg', siteId: 'site-1', takenAt: DateTime(2026, 3, 2)),
      );
      final early = await repository.createMedia(
        item(
          'map.pdf',
          siteId: 'site-1',
          mediaType: MediaType.document,
          takenAt: DateTime(2026, 3, 1),
        ),
      );
      await repository.createMedia(
        item('other.jpg', diveId: 'dive-1', takenAt: DateTime(2026, 3, 3)),
      );

      final result = await repository.getMediaForSite('site-1');
      expect(result.map((m) => m.id), [early.id, late1.id]);
      expect(result.first.mediaType, MediaType.document);
      expect(await repository.getMediaCountForSite('site-1'), 2);
      expect(await repository.getMediaCountForSite('site-none'), 0);
    });
  });

  group('site dedupe lookups', () {
    test('linked asset ids and local paths for site', () async {
      await insertSite('site-1');
      await repository.createMedia(
        item('a.jpg', siteId: 'site-1', platformAssetId: 'asset-9'),
      );
      await repository.createMedia(
        item(
          'map.pdf',
          siteId: 'site-1',
          mediaType: MediaType.document,
          sourceType: MediaSourceType.localFile,
          localPath: '/tmp/map.pdf',
        ),
      );

      expect(await repository.getLinkedAssetIdsForSite('site-1'), {'asset-9'});
      expect(await repository.getLinkedLocalPathsForSite('site-1'), {
        '/tmp/map.pdf',
      });
      expect(await repository.getLinkedAssetIdsForSite('site-2'), isEmpty);
      expect(await repository.getLinkedLocalPathsForSite('site-2'), isEmpty);
    });

    test(
      'a broken schema surfaces the failure instead of an empty set',
      () async {
        // An empty set would read as "nothing linked here yet" and let the
        // importer re-link every asset, so these lookups rethrow rather than
        // swallow. Dropping the table is the cheapest genuine query failure.
        // (Closing the database is NOT one: Drift answers a closed handle's
        // customSelect with an empty result rather than an error.)
        await db.customStatement('DROP TABLE media');

        await expectLater(
          repository.getLinkedAssetIdsForSite('site-1'),
          throwsA(anything),
        );
        await expectLater(
          repository.getLinkedLocalPathsForSite('site-1'),
          throwsA(anything),
        );
      },
    );
  });
}
