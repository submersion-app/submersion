import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/database/local_cache_database.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media_store/data/media_deletion_coordinator.dart';
import 'package:submersion/features/media_store/data/media_transfer_queue_repository.dart';

import '../../../../helpers/shared_items_fixture.dart';
import '../../../../helpers/test_database.dart';

/// Undo of a site bulk delete puts back what the delete cascaded away: the
/// site's expected species, features, types, tags and media (issue #2718).
void main() {
  late AppDatabase db;
  late LocalCacheDatabase cacheDb;
  late MediaTransferQueueRepository queue;
  late MediaRepository media;
  late SiteRepository sites;
  late int kicks;

  setUp(() async {
    db = await setUpTestDatabase();
    cacheDb = LocalCacheDatabase(NativeDatabase.memory());
    queue = MediaTransferQueueRepository(database: cacheDb);
    media = MediaRepository();
    kicks = 0;
    sites = SiteRepository(
      mediaRepository: media,
      mediaDeletionCoordinator: MediaDeletionCoordinator(
        mediaRepository: media,
        queue: () => queue,
        kickWorker: () async => kicks++,
      ),
    );
    await seedSite(db, 's1');
  });

  tearDown(() async {
    await cacheDb.close();
    await tearDownTestDatabase();
  });

  /// What the site list's Undo does: re-create the site, then its links.
  Future<void> deleteAndUndo() async {
    final site = (await sites.getSiteById('s1'))!;
    final links = await sites.bulkDeleteSites(['s1']);
    expect(await sites.getSiteById('s1'), isNull);
    await sites.createSite(site);
    await clearPendingMarks(db);
    await sites.restoreSiteLinks(links);
  }

  Future<void> seedChildren() async {
    await db
        .into(db.species)
        .insert(
          SpeciesCompanion.insert(
            id: 'turtle',
            commonName: 'Green turtle',
            category: 'reptile',
          ),
        );
    await db
        .into(db.siteSpecies)
        .insert(
          SiteSpeciesCompanion.insert(
            id: 'ss1',
            siteId: 's1',
            speciesId: 'turtle',
            notes: const Value('Mornings'),
            createdAt: kSharedTs,
          ),
        );
    await db
        .into(db.siteFeatures)
        .insert(
          SiteFeaturesCompanion.insert(
            id: 'f1',
            siteId: 's1',
            type: 'mooring',
            name: const Value('Buoy'),
            latitude: 12.1,
            longitude: -68.2,
            createdAt: kSharedTs,
            updatedAt: kSharedTs,
          ),
        );
    await db
        .into(db.siteTypes)
        .insert(
          SiteTypesCompanion.insert(
            id: 'custom-pinnacle',
            name: 'Pinnacle (custom)',
            createdAt: kSharedTs,
            updatedAt: kSharedTs,
          ),
        );
    await db
        .into(db.siteSiteTypes)
        .insert(
          SiteSiteTypesCompanion.insert(
            id: 'st1',
            siteId: 's1',
            siteTypeId: 'custom-pinnacle',
            createdAt: kSharedTs,
          ),
        );
    await db
        .into(db.tags)
        .insert(
          TagsCompanion.insert(
            id: 'fav',
            name: 'Favourite',
            createdAt: kSharedTs,
            updatedAt: kSharedTs,
          ),
        );
    await db
        .into(db.siteTags)
        .insert(
          SiteTagsCompanion.insert(
            id: 't1',
            siteId: 's1',
            tagId: 'fav',
            createdAt: kSharedTs,
          ),
        );
  }

  MediaItem photo(
    String id, {
    String? diveId,
    String? hash,
    DateTime? uploadedAt,
  }) => MediaItem(
    id: id,
    mediaType: MediaType.photo,
    originalFilename: '$id.jpeg',
    siteId: 's1',
    diveId: diveId,
    contentHash: hash,
    remoteUploadedAt: uploadedAt,
    takenAt: DateTime(2026),
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  test('brings back the site\'s species, features, types and tags under '
      'their ids, marked pending', () async {
    await seedChildren();
    await deleteAndUndo();

    final species = (await db.select(db.siteSpecies).get()).single;
    expect(
      (species.id, species.siteId, species.notes),
      ('ss1', 's1', 'Mornings'),
    );
    final feature = (await db.select(db.siteFeatures).get()).single;
    expect((feature.id, feature.name), ('f1', 'Buoy'));
    expect((await db.select(db.siteSiteTypes).get()).single.id, 'st1');
    expect((await db.select(db.siteTags).get()).single.id, 't1');
    for (final (entity, id) in [
      ('siteSpecies', 'ss1'),
      ('siteFeatures', 'f1'),
      ('siteSiteTypes', 'st1'),
      ('siteTags', 't1'),
    ]) {
      expect(await pendingCount(db, entity, id), 1, reason: entity);
    }
  });

  test('skips a species or tag deleted since and restores the rest', () async {
    await seedChildren();
    final site = (await sites.getSiteById('s1'))!;
    final links = await sites.bulkDeleteSites(['s1']);
    await db.customStatement("DELETE FROM species WHERE id = 'turtle'");
    await db.customStatement("DELETE FROM tags WHERE id = 'fav'");
    await sites.createSite(site);
    await sites.restoreSiteLinks(links);

    expect(await db.select(db.siteSpecies).get(), isEmpty);
    expect(await db.select(db.siteTags).get(), isEmpty);
    expect((await db.select(db.siteFeatures).get()).single.id, 'f1');
    expect((await db.select(db.siteSiteTypes).get()).single.id, 'st1');
  });

  test('brings back site-only media with its species tags, and relinks '
      'media a dive still holds', () async {
    await seedChildren();
    await seedDivers(db, ['a']);
    await seedDive(db, 'd1', diver: 'a');
    await media.createMedia(photo('only'));
    await media.createMedia(photo('shared', diveId: 'd1'));
    await db
        .into(db.mediaSpecies)
        .insert(
          MediaSpeciesCompanion.insert(
            id: 'ms1',
            mediaId: 'only',
            speciesId: 'turtle',
            createdAt: kSharedTs,
          ),
        );

    final site = (await sites.getSiteById('s1'))!;
    final links = await sites.bulkDeleteSites(['s1']);
    final deleteClock = (await (db.select(
      db.deletionLog,
    )..where((t) => t.recordId.equals('only'))).getSingle()).hlc!;
    await sites.createSite(site);
    await clearPendingMarks(db);
    await sites.restoreSiteLinks(links);

    final only = await media.getMediaById('only');
    expect(only?.siteId, 's1');
    // media is clock-guarded: a peer that applied the delete revives the
    // row only for a clock newer than the delete's.
    final row = await (db.select(
      db.media,
    )..where((t) => t.id.equals('only'))).getSingle();
    expect(row.hlc!.compareTo(deleteClock), greaterThan(0));
    expect(await pendingCount(db, 'media', 'only'), 1);
    expect(await tombstoneCount(db, 'media'), 0);
    expect((await db.select(db.mediaSpecies).get()).single.id, 'ms1');
    expect(await pendingCount(db, 'mediaSpecies', 'ms1'), 1);
    final shared = await media.getMediaById('shared');
    expect((shared?.siteId, shared?.diveId), ('s1', 'd1'));
    expect(await pendingCount(db, 'media', 'shared'), 1);
  });

  group('remote blob deletes', () {
    setUp(() async {
      await media.createMedia(
        photo('up', hash: 'h1', uploadedAt: DateTime(2026, 2)),
      );
    });

    test('a bulk delete queues the blob delete but does not start the '
        'worker, so Undo can still cancel it', () async {
      await sites.bulkDeleteSites(['s1']);
      final intent = (await queue.allForTesting()).single;
      expect((intent.direction, intent.state), ('delete', 'pending'));
      expect(kicks, 0);
    });

    test(
      'a single delete, which has no Undo, still starts the worker',
      () async {
        await sites.deleteSite('s1');
        expect(kicks, 1);
      },
    );

    test('Undo before the drain keeps the upload stamps and lets the held '
        'delete no-op', () async {
      await deleteAndUndo();
      expect((await media.getMediaById('up'))?.remoteUploadedAt, isNotNull);
      final entries = await queue.allForTesting();
      expect(entries.map((e) => e.direction), ['delete']);
      expect(await media.countRowsWithHash('h1'), 1);
      expect(kicks, 0);
    });

    test('Undo after the drain clears the stale stamps and queues a '
        're-upload', () async {
      final site = (await sites.getSiteById('s1'))!;
      final links = await sites.bulkDeleteSites(['s1']);
      final intent = (await queue.allForTesting()).single;
      await queue.markDone(intent.id);
      await sites.createSite(site);
      await sites.restoreSiteLinks(links);

      expect((await media.getMediaById('up'))?.remoteUploadedAt, isNull);
      final upload = (await queue.allForTesting()).where(
        (e) => e.direction == 'upload',
      );
      expect(upload.map((e) => (e.mediaId, e.state)), [('up', 'pending')]);
      expect(kicks, 1);
    });
  });
}
