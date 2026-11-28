import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/held_media_export.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';
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

/// A device retired while away rebuilds from the cloud and replays what it
/// had not published. Media it held back from an older device is in no
/// cloud log, so it must ride through as unpublished too (issue #5122).
void main() {
  setUp(() async => setUpTestDatabase());
  tearDown(() => tearDownTestDatabase());

  Future<void> keep(String id) => MediaRepository().createMedia(
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

  test('held and newly kept media survive a rejoin after retirement', () async {
    final cloud = FakeCloudStorageProvider();
    final folder = await cloud.getOrCreateSyncFolder();
    await SiteRepository().createSite(const DiveSite(id: 'old', name: 'Old'));
    await seedPeerLog(cloud, 'old');
    await restampPeerWriterSchemaVersion(
      cloud,
      'old',
      writerSchemaVersion: heldMediaSchemaVersion - 1,
    );
    final svc = SyncService(
      syncRepository: SyncRepository(),
      serializer: SyncDataSerializer(),
      cloudProvider: cloud,
    );
    await keep('held');
    expect((await svc.performSync()).status, SyncResultStatus.success);
    expect(await HeldMediaStore().isHeld('held'), isTrue);
    // Kept while away, never published.
    await keep('offline');

    final deviceId = await SyncRepository().getDeviceId();
    await svc.deleteDeviceSyncFile(deviceId);
    await cloud.uploadFile(
      RetirementMarker(
        deviceId: deviceId,
        retiredAt: DateTime.now().millisecondsSinceEpoch,
      ).toBytes(),
      ChangesetLogLayout.retiredMarkerName(deviceId),
      folderId: folder,
    );

    expect((await svc.performSync()).status, SyncResultStatus.success);

    expect(await MediaRepository().getMediaById('held'), isNotNull);
    expect(await MediaRepository().getMediaById('offline'), isNotNull);
  });
}
