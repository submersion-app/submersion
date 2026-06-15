import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late String folder;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    // Tiny threshold: compact once 2 changesets sit past the base.
    writer = ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      PublishStateStore(db),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 2,
    );
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  Future<ChangesetWriteResult> publish() async {
    final deviceId = await SyncRepository().getDeviceId();
    final deletions = await SyncRepository().getAllDeletions();
    return writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: deletions,
    );
  }

  test(
    'compacts after the changeset threshold and prunes superseded files',
    () async {
      final deviceId = await SyncRepository().getDeviceId();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await publish(); // base @1
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publish(); // cs @2
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd3', diveNumber: 3),
      );
      final result =
          await publish(); // cs @3 -> headSeq-baseSeq == 2 -> compact

      expect(result.kind, ChangesetWriteKind.compacted);

      final manifest = SyncManifest.fromBytes(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
        ),
      );
      expect(
        manifest.headSeq,
        manifest.baseSeq,
        reason: 'fresh base: head == base',
      );
      expect(manifest.publishedHlcHigh, isNotNull);

      final files = await provider.listFiles(
        folderId: folder,
        namePattern: ChangesetLogLayout.prefix,
      );
      final staleCs = files.where((f) {
        final s = ChangesetLogLayout.changesetSeqOf(f.name);
        return s != null && s < manifest.baseSeq!;
      });
      expect(staleCs, isEmpty, reason: 'superseded changesets pruned');
      final staleBaseParts = files.where((f) {
        final b = ChangesetLogLayout.basePartOf(f.name);
        return b != null && b.baseSeq != manifest.baseSeq;
      });
      expect(staleBaseParts, isEmpty, reason: 'old base parts pruned');
    },
  );

  test('a compacted base carries the deletion log (no resurrection)', () async {
    final deviceId = await SyncRepository().getDeviceId();
    final diveRepo = DiveRepository();
    await diveRepo.createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish(); // base @1 (d1)
    await diveRepo.createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    await publish(); // cs @2 (d2)

    // Delete d1: a tombstone now lives in the deletion log.
    await diveRepo.deleteDive('d1');
    await diveRepo.createDive(
      createTestDiveWithBottomTime(id: 'd3', diveNumber: 3),
    );
    final result = await publish(); // cs @3 -> compaction
    expect(result.kind, ChangesetWriteKind.compacted);

    // The compacted base must still carry the d1 tombstone; otherwise a peer
    // that holds d1 and cold-starts from this base would resurrect it.
    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );
    final parts = [
      for (var i = 0; i < (manifest.basePartCount ?? 0); i++)
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.basePartName(deviceId, manifest.baseSeq!, i)}',
        ),
    ];
    final base = ChangesetCodec(SyncDataSerializer()).decodeBaseParts(parts);
    final deletedIds = base.deletions.values
        .expand((l) => l)
        .map((d) => d.id)
        .toList();
    expect(
      deletedIds,
      contains('d1'),
      reason: 'compaction must preserve tombstones or deletes resurrect',
    );
  });

  test('does not compact below the threshold', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish(); // base @1
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final result = await publish(); // only 1 changeset past base
    expect(result.kind, ChangesetWriteKind.changeset);
  });
}
