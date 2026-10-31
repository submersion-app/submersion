import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/resumable_base_publish.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// A publish that needs no base still has to clear exports nothing will
/// resume: the next base may be months away, and nothing else reclaims this
/// directory (issue #3822).
void main() {
  late Directory publishDir;
  late ResumableBasePublishStore store;
  late FakeCloudStorageProvider provider;
  late String folder;

  ChangesetWriter writerWith(ResumableBasePublishStore resumableStore) {
    final serializer = SyncDataSerializer();
    return ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      PublishStateStore(DatabaseService.instance.database),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
      resumableStore: resumableStore,
    );
  }

  Future<ChangesetWriteResult> publish(ChangesetWriter writer) async {
    final repo = SyncRepository();
    return writer.publish(
      provider: provider,
      deviceId: await repo.getDeviceId(),
      folderId: folder,
      deletions: await repo.getAllDeletions(),
    );
  }

  /// A base has landed and nothing is pending, so the next publish has nothing
  /// to say.
  Future<void> publishBaseThenGoIdle() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish(writerWith(store));
    await SyncRepository().clearPendingRecords();
  }

  Future<String> parkExport({required String deviceId, Duration? age}) async {
    final path = p.join(publishDir.path, 'parked.json');
    await File(path).writeAsBytes(List.filled(50, 0x41));
    final parked = ResumableBasePublish(
      providerId: provider.providerId,
      deviceId: deviceId,
      seq: 1,
      dataPath: path,
      byteLength: 50,
      createdAt: 100,
    );
    await store.save(parked);
    if (age != null) {
      await File(
        parked.sidecarPath,
      ).setLastModified(DateTime.now().subtract(age));
    }
    return path;
  }

  setUp(() async {
    await setUpTestDatabase();
    publishDir = await Directory.systemTemp.createTemp('export_sweep');
    store = ResumableBasePublishStore(directory: () async => publishDir);
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });

  tearDown(() async {
    await tearDownTestDatabase();
    if (await publishDir.exists()) await publishDir.delete(recursive: true);
  });

  test('a publish that needs no base drops an export it outran', () async {
    // An app killed after the manifest committed but before the export was
    // discarded. A later forced base would resume these stale bytes, moving
    // the published seq and watermark backwards.
    await publishBaseThenGoIdle();
    final path = await parkExport(
      deviceId: await SyncRepository().getDeviceId(),
    );

    final result = await publish(writerWith(store));

    expect(result.kind, ChangesetWriteKind.noop);
    expect(await File(path).exists(), isFalse);
  });

  test('an ordinary publish reclaims an abandoned export', () async {
    await publishBaseThenGoIdle();
    final path = await parkExport(
      deviceId: 'old-id',
      age: const Duration(hours: 1),
    );

    final result = await publish(writerWith(store));

    expect(result.kind, ChangesetWriteKind.noop);
    expect(await File(path).exists(), isFalse);
  });

  test('a sweep that fails does not fail the publish', () async {
    await publishBaseThenGoIdle();
    final unreachable = ResumableBasePublishStore(
      directory: () async => throw const FileSystemException('denied'),
    );

    final result = await publish(writerWith(unreachable));

    expect(
      result.kind,
      ChangesetWriteKind.noop,
      reason: 'housekeeping for a publish that never needed an export',
    );
  });
}
