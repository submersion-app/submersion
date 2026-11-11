import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
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

/// Acks and heartbeats: what an empty publish does with the device's own
/// manifest. Split from changeset_writer_test.dart, which covers the data
/// path (bases, changesets, compaction).
void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late String folder;

  /// A writer as SyncService builds one per launch.
  ChangesetWriter newWriter() => ChangesetWriter(
    SyncDataSerializer(),
    const ChangesetCodec(),
    PublishStateStore(DatabaseService.instance.database),
    compactionByteRatio: 1000.0,
    compactionMaxChangesets: 1 << 30,
  );

  setUp(() async {
    await setUpTestDatabase();
    writer = newWriter();
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
  });
  tearDown(() => tearDownTestDatabase());

  const dayMillis = 24 * 60 * 60 * 1000;

  /// Clears the pending marks a publish covered, as SyncService does after
  /// every publish, so the next publish has nothing left to say.
  Future<void> clearCovered(ChangesetWriteResult result) async {
    final snapshotAt = result.snapshotAt;
    if (snapshotAt != null) {
      await SyncRepository().clearPendingRecords(markedBefore: snapshotAt);
    }
  }

  /// Steps past the millisecond a test seeded in, so the publish covers it
  /// (the pending-mark cutoff is strict).
  Future<void> publishLater() =>
      Future<void>.delayed(const Duration(milliseconds: 2));

  Future<SyncManifest> downloadManifest(String deviceId) async =>
      SyncManifest.fromBytes(
        await provider.downloadFile(
          '$folder/${ChangesetLogLayout.manifestName(deviceId)}',
        ),
      );

  /// Publishes one dive as nonce 'nonce-1' under [deviceName] and returns the
  /// manifest that landed.
  Future<({String deviceId, SyncManifest fresh})> publishOneDive(
    String diveId, {
    String? deviceName,
  }) async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: diveId, diveNumber: 1),
    );
    final deviceId = await SyncRepository().getDeviceId();
    await publishLater();
    await clearCovered(
      await writer.publish(
        provider: provider,
        deviceId: deviceId,
        folderId: folder,
        deletions: const [],
        uploadNonce: 'nonce-1',
        deviceName: deviceName,
      ),
    );
    return (deviceId: deviceId, fresh: await downloadManifest(deviceId));
  }

  /// Replaces the device's cloud manifest with [fresh] overlaid by
  /// [overrides], as raw JSON so every other field carries over and a key
  /// can be set to null (a field an older build never wrote).
  Future<void> restamp(SyncManifest fresh, Map<String, Object?> overrides) =>
      provider.uploadFile(
        SyncManifest.fromJson({...fresh.toJson(), ...overrides}).toBytes(),
        ChangesetLogLayout.manifestName(fresh.deviceId),
        folderId: folder,
      );

  Future<ChangesetWriteResult> emptyPublish(
    String deviceId, {
    String? deviceName,
    Map<String, String> appliedPeerHlc = const {},
  }) async => writer.publish(
    provider: provider,
    deviceId: deviceId,
    folderId: folder,
    deletions: await SyncRepository().getAllDeletions(),
    deviceName: deviceName,
    appliedPeerHlc: appliedPeerHlc,
  );

  /// The log [after] points at is the one [fresh] pointed at.
  void expectSameLog(SyncManifest after, SyncManifest fresh) {
    expect(after.baseSeq, fresh.baseSeq);
    expect(after.basePartCount, fresh.basePartCount);
    expect(after.baseChecksum, fresh.baseChecksum);
    expect(after.headSeq, fresh.headSeq);
    expect(after.publishedHlcHigh, fresh.publishedHlcHigh);
    expect(after.uploadNonce, 'nonce-1');
  }

  test('publish stamps appliedPeerHlc into the manifest', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'ack-d1', diveNumber: 1),
    );
    final deviceId = await SyncRepository().getDeviceId();
    await writer.publish(
      provider: provider,
      deviceId: deviceId,
      folderId: folder,
      deletions: const [],
      appliedPeerHlc: const {'peer-a': '00000000000010:000000:peer-a'},
    );
    final manifest = await downloadManifest(deviceId);
    expect(manifest.appliedPeerHlc, {'peer-a': '00000000000010:000000:peer-a'});
  });

  test(
    'empty publish heartbeats a stale manifest, preserving base and nonce',
    () async {
      final setup = await publishOneDive('hb-d1');
      // Age the manifest 8 days (past the 7-day heartbeat threshold).
      await restamp(setup.fresh, {
        'updatedAt': DateTime.now().millisecondsSinceEpoch - 8 * dayMillis,
      });

      final result = await emptyPublish(
        setup.deviceId,
        appliedPeerHlc: const {'peer-a': '00000000000099:000000:peer-a'},
      );

      expect(result.kind, ChangesetWriteKind.heartbeat);
      final after = await downloadManifest(setup.deviceId);
      expectSameLog(after, setup.fresh);
      expect(after.appliedPeerHlc, {'peer-a': '00000000000099:000000:peer-a'});
      expect(
        DateTime.now().millisecondsSinceEpoch - after.updatedAt,
        lessThan(60 * 1000),
      );
    },
  );

  test('empty publish against a fresh manifest stays a noop', () async {
    final setup = await publishOneDive('noop-d1');
    expect((await emptyPublish(setup.deviceId)).kind, ChangesetWriteKind.noop);
  });

  test('a heartbeat keeps the published compatibility floor', () async {
    // The floor describes the payloads in the log, and a heartbeat publishes
    // none: raising it would hold older peers off a log they can still read.
    final setup = await publishOneDive('floor-d1');
    const oldFloor = AppDatabase.minimumCompatibleSchemaVersion - 1;
    await restamp(setup.fresh, {
      'schemaVersion': oldFloor,
      'updatedAt': DateTime.now().millisecondsSinceEpoch - 8 * dayMillis,
    });

    expect(
      (await emptyPublish(setup.deviceId)).kind,
      ChangesetWriteKind.heartbeat,
    );
    expect((await downloadManifest(setup.deviceId)).schemaVersion, oldFloor);
  });

  group('a fresh manifest that no longer describes this build (#4462)', () {
    test('an older build\'s writer stamp is republished on the first '
        'empty publish after an update', () async {
      // Written by the build before the update: peers on this build read
      // the old writer schema as "below my floor" and warn about it.
      final setup = await publishOneDive('stamp-d1');
      const oldFloor = AppDatabase.minimumCompatibleSchemaVersion - 5;
      await restamp(setup.fresh, {
        'schemaVersion': oldFloor,
        'writerSchemaVersion': AppDatabase.minimumCompatibleSchemaVersion - 1,
      });

      final result = await emptyPublish(setup.deviceId);

      expect(result.kind, ChangesetWriteKind.heartbeat);
      final after = await downloadManifest(setup.deviceId);
      expect(after.writerSchemaVersion, AppDatabase.currentSchemaVersion);
      // Still the same log, written under the same floor: only the writer
      // stamp changed.
      expect(after.schemaVersion, oldFloor);
      expectSameLog(after, setup.fresh);
    });

    test('a manifest from before writerSchemaVersion existed is '
        'republished', () async {
      // Before the field existed, schemaVersion carried the writer's actual
      // schema, not a floor. Left beside a fresh writer stamp it would read
      // as a floor and hold peers that can apply this log.
      final setup = await publishOneDive('stamp-d2');
      await restamp(setup.fresh, {
        'writerSchemaVersion': null,
        'schemaVersion': AppDatabase.currentSchemaVersion,
      });

      final result = await emptyPublish(setup.deviceId);

      expect(result.kind, ChangesetWriteKind.heartbeat);
      final after = await downloadManifest(setup.deviceId);
      expect(after.writerSchemaVersion, AppDatabase.currentSchemaVersion);
      expect(after.schemaVersion, AppDatabase.minimumCompatibleSchemaVersion);
      expectSameLog(after, setup.fresh);
    });

    test('a legacy writer schema below this build\'s floor is kept as the '
        'floor', () async {
      final setup = await publishOneDive('stamp-d4');
      const legacy = AppDatabase.minimumCompatibleSchemaVersion - 1;
      await restamp(setup.fresh, {
        'writerSchemaVersion': null,
        'schemaVersion': legacy,
      });

      expect(
        (await emptyPublish(setup.deviceId)).kind,
        ChangesetWriteKind.heartbeat,
      );
      expect((await downloadManifest(setup.deviceId)).schemaVersion, legacy);
    });

    test('an old floor alone, under this build\'s writer stamp, stays a '
        'noop', () async {
      // Nothing for peers to misread: they warn on the writer stamp, and
      // the floor is the log's to change, not a heartbeat's.
      final setup = await publishOneDive('stamp-d3');
      await restamp(setup.fresh, {
        'schemaVersion': AppDatabase.minimumCompatibleSchemaVersion - 1,
      });

      expect(
        (await emptyPublish(setup.deviceId)).kind,
        ChangesetWriteKind.noop,
      );
    });

    test('corrects once per launch, so twins on different builds do not '
        'overwrite each other on every sync', () async {
      final setup = await publishOneDive('twin-d1', deviceName: 'Mac');
      final twinStamp = {
        'writerSchemaVersion': AppDatabase.currentSchemaVersion - 1,
        'deviceName': 'Old Mac',
      };
      await restamp(setup.fresh, twinStamp);
      expect(
        (await emptyPublish(setup.deviceId, deviceName: 'Mac')).kind,
        ChangesetWriteKind.heartbeat,
      );

      // A twin on the older build stamps its own build and name back. It
      // shares the nonce, so nothing flags it as a twin; this writer leaves
      // its stamps rather than fighting over them each sync.
      await restamp(await downloadManifest(setup.deviceId), twinStamp);
      expect(
        (await emptyPublish(setup.deviceId, deviceName: 'Mac')).kind,
        ChangesetWriteKind.noop,
      );

      // The next launch starts a new writer, which corrects once more.
      writer = newWriter();
      expect(
        (await emptyPublish(setup.deviceId, deviceName: 'Mac')).kind,
        ChangesetWriteKind.heartbeat,
      );
      final after = await downloadManifest(setup.deviceId);
      expect(after.writerSchemaVersion, AppDatabase.currentSchemaVersion);
      expect(after.deviceName, 'Mac');
    });

    test('a renamed device republishes its new name', () async {
      final setup = await publishOneDive('name-d1', deviceName: 'Old iPad');

      final result = await emptyPublish(
        setup.deviceId,
        deviceName: 'Dive iPad',
      );

      expect(result.kind, ChangesetWriteKind.heartbeat);
      final after = await downloadManifest(setup.deviceId);
      expect(after.deviceName, 'Dive iPad');
      expectSameLog(after, setup.fresh);
    });

    test('a matching name, or none resolved, stays a noop', () async {
      final setup = await publishOneDive('name-d2', deviceName: 'Dive iPad');

      expect(
        (await emptyPublish(setup.deviceId, deviceName: 'Dive iPad')).kind,
        ChangesetWriteKind.noop,
      );
      // Nothing resolved a name this time: the heartbeat would keep the
      // published one anyway, so there is nothing to correct.
      expect(
        (await emptyPublish(setup.deviceId)).kind,
        ChangesetWriteKind.noop,
      );
    });
  });
}
