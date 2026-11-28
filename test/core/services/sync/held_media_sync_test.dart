import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/services/sync/held_media_export.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/data/repositories/media_species_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../features/media/data/repositories/species_photo_fixtures.dart';
import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// Media kept with no dive, site or gear stays away from a device whose
/// build would delete it, and goes out once that is safe (issue #5122).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<void> sync(FakeCloudStorageProvider cloud) async {
    final result = await SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    ).performSync();
    expect(result.isSuccess, isTrue);
  }

  /// A device in the library on a build before held media.
  Future<void> olderDevice(FakeCloudStorageProvider cloud) async {
    // An empty log publishes no manifest: give the device something to say.
    await SiteRepository().createSite(const DiveSite(id: 'old', name: 'Old'));
    await seedPeerLog(cloud, 'old');
    await restampPeerWriterSchemaVersion(
      cloud,
      'old',
      writerSchemaVersion: heldMediaSchemaVersion - 1,
    );
  }

  Future<void> updateOlderDevice(FakeCloudStorageProvider cloud) =>
      restampPeerWriterSchemaVersion(
        cloud,
        'old',
        writerSchemaVersion: heldMediaSchemaVersion,
      );

  Future<void> keep(String id, {String? siteId, bool retain = true}) async {
    await MediaRepository().createMedia(
      MediaItem(
        id: id,
        mediaType: MediaType.video,
        sourceType: MediaSourceType.localFile,
        filePath: p.join(Directory.systemTemp.path, 'clips', '$id.mp4'),
        localPath: p.join(Directory.systemTemp.path, 'clips', '$id.mp4'),
        siteId: siteId,
        retainInLibrary: retain,
        takenAt: DateTime.utc(2026, 11, 1),
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await MediaSpeciesRepository().addTag(mediaId: id, speciesId: 'sp');
  }

  /// What a fresh device on this build receives from the cloud.
  Future<({bool row, int tags})> freshDeviceSees(
    FakeCloudStorageProvider cloud,
    String id,
  ) async {
    await tearDownTestDatabase();
    await setUpTestDatabase();
    await sync(cloud);
    final tags = await DatabaseService.instance.database
        .customSelect("SELECT 1 FROM media_species WHERE media_id = '$id'")
        .get();
    return (
      row: await MediaRepository().getMediaById(id) != null,
      tags: tags.length,
    );
  }

  test(
    'with an older device, kept media and its tag stay out of the base',
    () async {
      final cloud = FakeCloudStorageProvider();
      await olderDevice(cloud);
      await insertTestSpecies(id: 'sp', name: 'Green sea turtle');
      await keep('clip');
      await keep('placed', siteId: null, retain: false);

      await sync(cloud);

      expect(await HeldMediaStore().heldIds(), {'clip'});
      final seen = await freshDeviceSees(cloud, 'clip');
      expect(seen.row, isFalse);
      expect(seen.tags, 0);
    },
  );

  test(
    'with an older device, kept media stays out of a later changeset',
    () async {
      final cloud = FakeCloudStorageProvider();
      await olderDevice(cloud);
      await insertTestSpecies(id: 'sp', name: 'Green sea turtle');
      await sync(cloud);
      await keep('clip');

      await sync(cloud);

      expect((await freshDeviceSees(cloud, 'clip')).row, isFalse);
    },
  );

  test('with every device on this build, kept media goes out', () async {
    final cloud = FakeCloudStorageProvider();
    await SiteRepository().createSite(const DiveSite(id: 'new', name: 'New'));
    await seedPeerLog(cloud, 'new');
    await insertTestSpecies(id: 'sp', name: 'Green sea turtle');
    await keep('clip');

    await sync(cloud);

    expect(await HeldMediaStore().heldIds(), isEmpty);
    final seen = await freshDeviceSees(cloud, 'clip');
    expect(seen.row, isTrue);
    expect(seen.tags, 1);
  });

  test(
    'once the older device updates, the held row and its tag go out',
    () async {
      final cloud = FakeCloudStorageProvider();
      await olderDevice(cloud);
      await insertTestSpecies(id: 'sp', name: 'Green sea turtle');
      await keep('clip');
      await sync(cloud);
      await updateOlderDevice(cloud);

      await sync(cloud);

      expect(await HeldMediaStore().heldIds(), isEmpty);
      final seen = await freshDeviceSees(cloud, 'clip');
      expect(seen.row, isTrue);
      expect(seen.tags, 1);
    },
  );

  test('a held row placed on a site goes out with its tag', () async {
    final cloud = FakeCloudStorageProvider();
    await olderDevice(cloud);
    await insertTestSpecies(id: 'sp', name: 'Green sea turtle');
    await SiteRepository().createSite(const DiveSite(id: 's1', name: 'Reef'));
    await keep('clip');
    await sync(cloud);
    await MediaRepository().linkMediaToSite(['clip'], 's1');

    await sync(cloud);

    expect(await HeldMediaStore().heldIds(), isEmpty);
    final seen = await freshDeviceSees(cloud, 'clip');
    expect(seen.row, isTrue);
    expect(seen.tags, 1);
  });

  test('an older device\'s delete of a held row is not applied', () async {
    final cloud = FakeCloudStorageProvider();
    await olderDevice(cloud);
    await insertTestSpecies(id: 'sp', name: 'Green sea turtle');
    await keep('clip');
    await sync(cloud);
    // The older device's sweep deleted its copy and logged the delete.
    final db = DatabaseService.instance.database;
    await SyncRepository().logDeletion(entityType: 'media', recordId: 'clip');
    await publishOwnLog(cloud, 'old');
    await restampPeerWriterSchemaVersion(
      cloud,
      'old',
      writerSchemaVersion: heldMediaSchemaVersion - 1,
    );
    await db.customStatement(
      "DELETE FROM deletion_log WHERE record_id = 'clip'",
    );

    await sync(cloud);

    expect(await MediaRepository().getMediaById('clip'), isNotNull);
  });
}
