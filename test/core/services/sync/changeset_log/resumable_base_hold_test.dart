import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/resumable_base_publish.dart';
import 'package:submersion/core/services/sync/held_media_store.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/media/data/repositories/media_repository.dart';
import 'package:submersion/features/media/domain/entities/media_item.dart';
import 'package:submersion/features/media/domain/entities/media_source_type.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// A base export cut short is resumed only if it holds back what this
/// publish must: media kept with no place, once an older device is in the
/// library (issue #5122).
void main() {
  late Directory publishDir;
  late ResumableBasePublishStore store;
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late String folder;

  setUp(() async {
    await setUpTestDatabase();
    publishDir = await Directory.systemTemp.createTemp('base_hold');
    store = ResumableBasePublishStore(directory: () async => publishDir);
    writer = ChangesetWriter(
      SyncDataSerializer(),
      const ChangesetCodec(),
      PublishStateStore(DatabaseService.instance.database),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
      resumableStore: store,
    );
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
    // Something every export carries, held or not.
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await MediaRepository().createMedia(
      MediaItem(
        id: 'clip',
        mediaType: MediaType.video,
        sourceType: MediaSourceType.localFile,
        filePath: p.join(Directory.systemTemp.path, 'clips', 'clip.mp4'),
        localPath: p.join(Directory.systemTemp.path, 'clips', 'clip.mp4'),
        retainInLibrary: true,
        takenAt: DateTime.utc(2026, 11, 1),
        createdAt: DateTime.utc(2026, 11, 1),
        updatedAt: DateTime.utc(2026, 11, 1),
      ),
    );
  });

  tearDown(() async {
    await tearDownTestDatabase();
    if (await publishDir.exists()) await publishDir.delete(recursive: true);
  });

  Future<ChangesetWriteResult> publish({required bool holding}) async {
    final repo = SyncRepository();
    return writer.publish(
      provider: provider,
      deviceId: await repo.getDeviceId(),
      folderId: folder,
      deletions: await repo.getAllDeletions(),
      holdUnplacedMedia: holding,
    );
  }

  /// A base publish cut short on its first part, leaving its export.
  Future<ResumableBasePublish> interrupted({required bool holding}) async {
    provider.failUploadsAfter = 0;
    await expectLater(publish(holding: holding), throwsA(anything));
    provider.failUploadsAfter = null;
    return (await store.find(
      providerId: provider.providerId,
      deviceId: await SyncRepository().getDeviceId(),
    ))!;
  }

  test('an export made with nothing held is made again once media is '
      'held', () async {
    final pending = await interrupted(holding: false);
    expect(pending.heldUnplacedMedia, isFalse);

    final result = await publish(holding: true);

    expect(result.kind, ChangesetWriteKind.base);
    expect(
      result.snapshotAt,
      isNotNull,
      reason: 'a fresh export, read now, not the one that carries the clip',
    );
    expect(await File(pending.dataPath).exists(), isFalse);
    expect(await HeldMediaStore().isHeld('clip'), isTrue);
  });

  test('an export that held media is resumed once nothing is held: the '
      'release sends what it left out', () async {
    final pending = await interrupted(holding: true);
    expect(pending.heldUnplacedMedia, isTrue);

    final result = await publish(holding: false);

    expect(result.kind, ChangesetWriteKind.base);
    expect(result.seq, pending.seq);
    expect(result.snapshotAt, isNull, reason: 'the export was resumed');
  });

  test('a record written before held media reads as holding nothing', () {
    final json = const ResumableBasePublish(
      providerId: 'fake',
      deviceId: 'dev1',
      seq: 1,
      dataPath: 'base.json',
      byteLength: 1,
      createdAt: 1,
      heldUnplacedMedia: true,
    ).toJson();
    expect(ResumableBasePublish.fromJson(json).heldUnplacedMedia, isTrue);
    expect(
      ResumableBasePublish.fromJson(
        {...json}..remove('heldUnplacedMedia'),
      ).heldUnplacedMedia,
      isNull,
    );
  });
}
