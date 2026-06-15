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
    writer = ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      PublishStateStore(db),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
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

  Future<List<String>> names() async {
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    return files.map((f) => f.name).toList();
  }

  test('first publish with data writes a base + manifest', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.base);

    final deviceId = await SyncRepository().getDeviceId();
    final ns = await names();
    expect(ns, contains(ChangesetLogLayout.manifestName(deviceId)));
    expect(ns.any((n) => ChangesetLogLayout.basePartOf(n) != null), isTrue);

    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );
    expect(manifest.baseSeq, isNotNull);
    expect(manifest.headSeq, manifest.baseSeq);
    expect(manifest.publishedHlcHigh, isNotNull);
    expect(manifest.basePartChecksums, isNotEmpty);
  });

  test('publish with no data is a no-op', () async {
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
    expect(await names(), isEmpty);
  });

  test(
    'cold-starts a fresh base (no crash) when local state has a base but the '
    'cloud manifest is missing',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publish(); // base @1, manifest + local publish state

      // The cloud manifest becomes un-listable (eventual-consistency lag, or
      // wiped by another device) while local publish state still says a base
      // exists. Regression: the changeset branch did `ownManifest!` and threw
      // "Null check operator used on a null value" on the next publish.
      final deviceId = await SyncRepository().getDeviceId();
      await provider.deleteFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      );

      // Delete a dive and publish -- must recover, not throw.
      await DiveRepository().deleteDive('d1');
      final result = await publish();

      expect(
        result.kind,
        ChangesetWriteKind.base,
        reason: 'a missing cloud manifest must cold-start a fresh base',
      );
      final manifest = SyncManifest.fromBytes(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
        ),
      );
      expect(
        manifest.baseSeq,
        greaterThan(1),
        reason: 'the fresh base uses a non-reused seq recovered from state',
      );
    },
  );

  test('second publish writes a changeset with only the new dive', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.changeset);

    final deviceId = await SyncRepository().getDeviceId();
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final csFiles = files
        .where((f) => ChangesetLogLayout.changesetSeqOf(f.name) != null)
        .toList();
    expect(csFiles, isNotEmpty);

    final payload = ChangesetCodec(
      SyncDataSerializer(),
    ).decodeChangeset(await provider.downloadFile(csFiles.first.id));
    final diveIds = payload.data.dives.map((d) => d['id']).toSet();
    expect(diveIds.contains('d2'), isTrue);
    expect(diveIds.contains('d1'), isFalse);

    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(
        '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
      ),
    );
    expect(manifest.headSeq, greaterThan(manifest.baseSeq!));
  });

  test('publish after base with no new changes is a no-op', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    final before = (await names()).length;

    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
    expect(
      (await names()).length,
      before,
      reason: 'a no-op writes no new file',
    );
  });

  test(
    'lost local publish state recovers headSeq from the cloud manifest',
    () async {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await publish(); // base @ seq 1
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await publish(); // changeset @ seq 2

      await PublishStateStore(
        DatabaseService.instance.database,
      ).resetForProvider(provider.providerId);

      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd3', diveNumber: 3),
      );
      final result = await publish();
      expect(result.kind, ChangesetWriteKind.changeset);
      expect(
        result.seq,
        3,
        reason: 'seq must continue from the cloud manifest, not reset to 1',
      );
    },
  );
}
