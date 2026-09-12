import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/equipment/data/repositories/equipment_repository_impl.dart';

import '../../../helpers/changeset_test_helpers.dart';
import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/mock_providers.dart';
import '../../../helpers/test_database.dart';

/// A cleared cylinder link reaches peers without re-stamping its dive, so a
/// peer's newer edit to that dive is never overwritten by this device's
/// stale copy, and a pending mark made while a publish is in flight is not
/// wiped before it is sent.
void main() {
  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });
  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService([CloudStorageProvider? provider]) => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: provider ?? cloud,
  );

  /// A synced dive whose tank is linked to gear item 'cyl', published
  /// through [provider] (the shared fake by default).
  Future<void> seedSyncedDiveWithLinkedTank([
    CloudStorageProvider? provider,
  ]) async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(
        id: 'd1',
        diveNumber: 1,
      ).copyWith(name: 'Original'),
    );
    final db = DatabaseService.instance.database;
    await db.customStatement(
      "INSERT INTO equipment (id, name, type, created_at, updated_at) "
      "VALUES ('cyl', 'Blue AL80', 'tank', 1, 1)",
    );
    await db.customStatement(
      'INSERT INTO dive_tanks (id, dive_id, equipment_id) '
      "VALUES ('t1', 'd1', 'cyl')",
    );
    final first = await buildService(provider).performSync();
    expect(first.status, isNot(SyncResultStatus.error), reason: 'precondition');
  }

  /// What a peer rebuilds from this device's log: its base, then every
  /// changeset after it in order, as id -> row for [entity] (`dives` or
  /// `diveTanks`). A publish may compact into a fresh base, so the base
  /// alone is not enough, and neither is the newest changeset.
  Future<Map<String, Map<String, dynamic>>> publishedView(String entity) async {
    final deviceId = await SyncRepository().getDeviceId();
    final manifest = (await ownManifest(cloud, deviceId))!;
    final view = <String, Map<String, dynamic>>{};
    void overlay(SyncData data) {
      final rows = entity == 'dives' ? data.dives : data.diveTanks;
      for (final row in rows) {
        view[row['id'] as String] = row;
      }
    }

    final base = await cloudBasePayload(cloud, deviceId);
    if (base != null) overlay(base.data);
    final folder = await cloud.getOrCreateSyncFolder();
    final files = await cloud.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.prefix,
    );
    final changesets =
        [
          for (final f in files)
            if (f.name.contains(deviceId) &&
                (ChangesetLogLayout.changesetSeqOf(f.name) ?? 0) >
                    (manifest.baseSeq ?? 0))
              f,
        ]..sort(
          (a, b) => ChangesetLogLayout.changesetSeqOf(
            a.name,
          )!.compareTo(ChangesetLogLayout.changesetSeqOf(b.name)!),
        );
    final codec = ChangesetCodec(SyncDataSerializer());
    for (final f in changesets) {
      overlay(codec.decodeChangeset(await cloud.downloadFile(f.id)).data);
    }
    return view;
  }

  test('a peer\'s newer rename survives this device deleting the gear its '
      'cylinder was linked to', () async {
    await seedSyncedDiveWithLinkedTank();
    final serializer = SyncDataSerializer();
    final synced = (await serializer.fetchRecord('dives', 'd1'))!;
    final ours = Hlc.parse(synced['hlc'] as String);

    // Device B renames the dive while this device is offline. Its edit is
    // newer than the copy both devices share...
    final theirs = {
      ...synced,
      'name': 'Renamed by B',
      'hlc': Hlc(ours.physicalTime + 1, 0, 'peer-b').toString(),
    };
    // ...but older than this device deleting the gear, which happens later.
    await Future<void>.delayed(const Duration(milliseconds: 5));
    await EquipmentRepository().deleteEquipment('cyl');

    final peerData = SyncData(dives: [theirs]);
    await seedPeerBaseFromPayload(
      cloud,
      'peer-b',
      SyncPayload(
        version: syncFormatVersion,
        exportedAt: 9000,
        deviceId: 'peer-b',
        checksum: sha256
            .convert(utf8.encode(jsonEncode(peerData.toJson())))
            .toString(),
        data: peerData,
        deletions: const {},
      ),
    );

    final result = await buildService().performSync();
    expect(result.status, isNot(SyncResultStatus.error));

    final dive = (await serializer.fetchRecord('dives', 'd1'))!;
    expect(
      dive['name'],
      'Renamed by B',
      reason:
          'deleting gear did not edit the dive, so it must not outrank '
          'a real edit made elsewhere',
    );
    // What any other device now receives from this one.
    final dives = await publishedView('dives');
    expect(
      dives['d1']?['name'],
      isNot('Original'),
      reason: 'a stale copy of the dive must not be published',
    );
    final tanks = await publishedView('diveTanks');
    expect(tanks['t1'], isNotNull, reason: 'the cleared tank is published');
    expect(tanks['t1']!['equipmentId'], isNull);
  });

  test(
    'a pending mark made while a publish is in flight survives it',
    () async {
      final racing = _MarkDuringUpload(() async {
        await SyncRepository().markRecordPending(
          entityType: 'diveTanks',
          recordId: 't1',
          localUpdatedAt: DateTime.now().millisecondsSinceEpoch,
        );
      });
      // The first publish is a base, which the hook ignores.
      await seedSyncedDiveWithLinkedTank(racing);
      expect(racing.fired, isFalse, reason: 'precondition');
      // A change so the publish has something to send.
      await EquipmentRepository().deleteEquipment('cyl');

      final result = await buildService(racing).performSync();
      expect(result.status, isNot(SyncResultStatus.error));
      expect(racing.fired, isTrue, reason: 'precondition');

      final db = DatabaseService.instance.database;
      final pending = await (db.select(
        db.syncRecords,
      )..where((r) => r.syncStatus.equals('pending'))).get();
      expect(
        pending.map((r) => '${r.entityType}/${r.recordId}'),
        contains('diveTanks/t1'),
        reason:
            'marked after the snapshot was read, so it is not in what was '
            'sent and must go out with the next publish',
      );
    },
  );
}

/// Runs [onFirstUpload] once, just before the first file of a publish lands:
/// after the export snapshot was read and before the post-publish clear.
class _MarkDuringUpload extends FakeCloudStorageProvider {
  _MarkDuringUpload(this.onFirstUpload);

  final Future<void> Function() onFirstUpload;
  var fired = false;

  @override
  Future<UploadResult> uploadFile(
    Uint8List data,
    String filename, {
    String? folderId,
  }) async {
    if (!fired && ChangesetLogLayout.changesetSeqOf(filename) != null) {
      fired = true;
      // Later than the snapshot read, in the millisecond clock the cutoff
      // compares against.
      await Future<void>.delayed(const Duration(milliseconds: 2));
      await onFirstUpload();
    }
    return super.uploadFile(data, filename, folderId: folderId);
  }
}
