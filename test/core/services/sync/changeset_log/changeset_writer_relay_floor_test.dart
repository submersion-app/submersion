import 'package:flutter_test/flutter_test.dart';
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

  Future<List<String>> latestChangesetDiveIds() async {
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
    final payload = ChangesetCodec(
      SyncDataSerializer(),
    ).decodeChangeset(await provider.downloadFile(cs.last.id));
    return payload.data.dives.map((d) => d['id'] as String).toList();
  }

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
}
