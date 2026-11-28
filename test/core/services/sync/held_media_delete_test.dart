import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/held_media_export.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_sites/data/repositories/site_repository_impl.dart';
import 'package:submersion/features/dive_sites/domain/entities/dive_site.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/test_database.dart';
import '../../../support/fake_cloud_storage_provider.dart';

/// Media held back from an older device ignores that device's delete (its
/// orphan sweep or a delete cascade) but takes a delete the diver made on a
/// device whose build keeps media with no place (issue #5122).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  SyncService service(FakeCloudStorageProvider cloud) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  Future<void> sync(FakeCloudStorageProvider cloud) async {
    final result = await service(cloud).performSync();
    expect(result.isSuccess, isTrue);
  }

  /// A library with a device on a build before held media, and [id] kept
  /// with no place here, so held back.
  Future<FakeCloudStorageProvider> holding(String id) async {
    final cloud = FakeCloudStorageProvider();
    await SiteRepository().createSite(const DiveSite(id: 'old', name: 'Old'));
    await seedPeerLog(cloud, 'old');
    await restampPeerWriterSchemaVersion(
      cloud,
      'old',
      writerSchemaVersion: heldMediaSchemaVersion - 1,
    );
    await MediaRepository().createMedia(
      MediaItem(
        id: id,
        mediaType: MediaType.video,
        sourceType: MediaSourceType.localFile,
        filePath: p.join(Directory.systemTemp.path, 'clips', '$id.mp4'),
        localPath: p.join(Directory.systemTemp.path, 'clips', '$id.mp4'),
        retainInLibrary: true,
        takenAt: DateTime.utc(2026, 11, 1),
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
    await sync(cloud);
    expect(await HeldMediaStore().isHeld(id), isTrue);
    return cloud;
  }

  /// A payload from [deviceId] carrying only its delete of media [id],
  /// stamped after the row was written.
  SyncPayload deleteFrom(String deviceId, String id) {
    final at = DateTime.now().millisecondsSinceEpoch + 60000;
    const data = SyncData();
    return SyncPayload(
      version: syncFormatVersion,
      exportedAt: at,
      deviceId: deviceId,
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: {
        'media': [
          SyncDeletion(
            id: id,
            deletedAt: at,
            hlc: Hlc(at, 0, deviceId).toString(),
          ),
        ],
      },
    );
  }

  test('a delete from a nearby device on this build is applied', () async {
    final cloud = await holding('clip');

    await service(cloud).applyNearbyPayload(
      deleteFrom('tablet', 'clip'),
      lastSync: null,
      peerDeviceId: 'tablet',
      peerSchemaVersion: heldMediaSchemaVersion,
    );

    expect(await MediaRepository().getMediaById('clip'), isNull);
  });

  test('a delete from an older nearby device is not applied', () async {
    final cloud = await holding('clip');

    await service(cloud).applyNearbyPayload(
      deleteFrom('tablet', 'clip'),
      lastSync: null,
      peerDeviceId: 'tablet',
      peerSchemaVersion: heldMediaSchemaVersion - 1,
    );

    expect(await MediaRepository().getMediaById('clip'), isNotNull);
  });

  test(
    'a delete from a device whose build is not known is not applied',
    () async {
      final cloud = await holding('clip');

      await service(
        cloud,
      ).applyNearbyPayload(deleteFrom('tablet', 'clip'), lastSync: null);

      expect(await MediaRepository().getMediaById('clip'), isNotNull);
    },
  );

  test('a delete from a cloud device on this build is applied', () async {
    final cloud = await holding('clip');
    await seedPeerBaseFromPayload(
      cloud,
      'tablet',
      deleteFrom('tablet', 'clip'),
    );
    await restampPeerWriterSchemaVersion(
      cloud,
      'tablet',
      writerSchemaVersion: heldMediaSchemaVersion,
    );

    await sync(cloud);

    expect(await MediaRepository().getMediaById('clip'), isNull);
  });

  test('a delete from an older cloud device is not applied', () async {
    final cloud = await holding('clip');
    await seedPeerBaseFromPayload(
      cloud,
      'tablet',
      deleteFrom('tablet', 'clip'),
    );
    await restampPeerWriterSchemaVersion(
      cloud,
      'tablet',
      writerSchemaVersion: heldMediaSchemaVersion - 1,
    );

    await sync(cloud);

    expect(await MediaRepository().getMediaById('clip'), isNotNull);
  });

  group('isDeliberateHeldMediaDelete', () {
    final at = DateTime.utc(2026, 11, 28).millisecondsSinceEpoch;
    String hlc(String node) => Hlc(at, 0, node).toString();

    test('trusts only a device known to keep media with no place', () {
      final schemas = {
        'new': heldMediaSchemaVersion,
        'old': heldMediaSchemaVersion - 1,
      };
      expect(isDeliberateHeldMediaDelete(hlc('new'), schemas), isTrue);
      expect(isDeliberateHeldMediaDelete(hlc('old'), schemas), isFalse);
      expect(isDeliberateHeldMediaDelete(hlc('stranger'), schemas), isFalse);
      expect(isDeliberateHeldMediaDelete(null, schemas), isFalse);
      expect(isDeliberateHeldMediaDelete('garbled', schemas), isFalse);
    });
  });
}
