import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/mock_providers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// A row nearby sync applied from a device with no backend carries that
/// device's older clock, so the next cloud publish would skip it. The relay
/// floor makes the writer export from below it once (issue #3731).
void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late PublishStateStore state;
  late String folder;

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    state = PublishStateStore(db);
    writer = ChangesetWriter(
      serializer,
      ChangesetCodec(serializer),
      state,
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
    );
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });
  tearDown(() => tearDownTestDatabase());

  Future<ChangesetWriteResult> publish() async {
    await Future<void>.delayed(const Duration(milliseconds: 2));
    final result = await writer.publish(
      provider: provider,
      deviceId: await SyncRepository().getDeviceId(),
      folderId: folder,
      deletions: await SyncRepository().getAllDeletions(),
    );
    final at = result.snapshotAt;
    if (at != null) {
      await SyncRepository().clearPendingRecords(markedBefore: at);
    }
    return result;
  }

  Future<SyncManifest> manifest() async => SyncManifest.fromBytes(
    await provider.downloadFile(
      '$folder/${ChangesetLogLayout.manifestName(await SyncRepository().getDeviceId())}',
    ),
  );

  Future<SyncPayload> latestChangeset() async {
    final files = await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final cs =
        files
            .where((f) => ChangesetLogLayout.changesetSeqOf(f.name) != null)
            .toList()
          ..sort(
            (a, b) => ChangesetLogLayout.changesetSeqOf(
              a.name,
            )!.compareTo(ChangesetLogLayout.changesetSeqOf(b.name)!),
          );
    return ChangesetCodec(
      SyncDataSerializer(),
    ).decodeChangeset(await provider.downloadFile(cs.last.id));
  }

  Future<List<String>> latestChangesetDiveIds() async => [
    for (final d in (await latestChangeset()).data.dives) d['id'] as String,
  ];

  /// d1 published in a base; then d2 arrives over nearby with a clock older
  /// than what the base published. Returns that older clock.
  Future<String> seedRelayedDive() async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publish();
    final published = (await manifest()).publishedHlcHigh!;
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
    );
    final ms = int.parse(published.substring(0, 15)) - 1000;
    final relayed = '${ms.toString().padLeft(15, '0')}:000000:laptop';
    await DatabaseService.instance.database.customStatement(
      "UPDATE dives SET hlc = ? WHERE id = 'd2'",
      [relayed],
    );
    await SyncRepository().clearAllSyncRecords();
    return relayed;
  }

  test('without a floor the relayed dive never reaches the cloud', () async {
    await seedRelayedDive();
    final result = await publish();
    expect(result.kind, ChangesetWriteKind.noop);
  });

  test('a floor publishes rows since it once, never moves the watermark '
      'down, and clears itself', () async {
    final relayed = await seedRelayedDive();
    final before = (await manifest()).publishedHlcHigh!;
    await state.pullBackRelayFloor(relayed);

    final result = await publish();
    expect(result.kind, ChangesetWriteKind.changeset);
    expect(await latestChangesetDiveIds(), contains('d2'));
    final after = (await manifest()).publishedHlcHigh!;
    expect(after.compareTo(before), greaterThanOrEqualTo(0));

    final row = await state.get(provider.providerId);
    expect(row!.relayFloorHlc, isNull);
    expect(row.publishedHlcHigh, after);

    // Cleared: the next publish has nothing to say.
    expect((await publish()).kind, ChangesetWriteKind.noop);
  });

  test('a floor also publishes a relayed child edit whose parent is older '
      'than it (a tank edited on an old dive)', () async {
    final db = DatabaseService.instance.database;
    const old = '000000000001000:000000:laptop';
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'old', diveNumber: 1),
    );
    await db.customStatement("UPDATE dives SET hlc = ? WHERE id = 'old'", [
      old,
    ]);
    await db.customStatement(
      "INSERT INTO dive_tanks (id, dive_id, hlc) VALUES ('t1', 'old', ?)",
      [old],
    );
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 2),
    );
    await publish();
    final published = (await manifest()).publishedHlcHigh!;
    final ms = int.parse(published.substring(0, 15)) - 1000;
    final relayed = '${ms.toString().padLeft(15, '0')}:000000:laptop';
    // Nearby applied the laptop's tank edit; the dive itself is unchanged.
    await db.customStatement("UPDATE dive_tanks SET hlc = ? WHERE id = 't1'", [
      relayed,
    ]);
    await SyncRepository().clearAllSyncRecords();
    await state.pullBackRelayFloor(relayed);

    expect((await publish()).kind, ChangesetWriteKind.changeset);
    final tanks = (await latestChangeset()).data.diveTanks;
    expect(tanks.map((t) => t['id']), ['t1']);
  });

  test('a floor set while a publish is under way survives it (a nearby '
      'apply recorded during the upload)', () async {
    final relayed = await seedRelayedDive();
    // A second relayed dive arrives while the next publish uploads.
    final during = _UploadHookProvider(provider, () async {
      await state.pullBackRelayFloor(relayed);
    });
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd3', diveNumber: 3),
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await writer.publish(
      provider: during,
      deviceId: await SyncRepository().getDeviceId(),
      folderId: folder,
      deletions: await SyncRepository().getAllDeletions(),
    );
    expect(
      (await state.get(provider.providerId))!.relayFloorHlc,
      isNotNull,
      reason: 'the publish never exported from that floor',
    );
    // So the next publish carries the relayed dive.
    final next = await publish();
    expect(next.kind, ChangesetWriteKind.changeset);
    expect(await latestChangesetDiveIds(), contains('d2'));
  });
}

/// Delegates to [inner], running [onUpload] once inside the first upload.
class _UploadHookProvider extends FakeCloudStorageProvider {
  _UploadHookProvider(this.inner, this.onUpload);

  final FakeCloudStorageProvider inner;
  Future<void> Function()? onUpload;

  @override
  String get providerId => inner.providerId;

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    final hook = onUpload;
    onUpload = null;
    if (hook != null) await hook();
    return inner.uploadFile(data, filename, folderId: folderId);
  }

  @override
  Future<Uint8List> downloadFile(String fileId) => inner.downloadFile(fileId);

  @override
  Future<List<CloudFileInfo>> listFiles({
    String? folderId,
    String? namePattern,
  }) => inner.listFiles(folderId: folderId, namePattern: namePattern);
}
