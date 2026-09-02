// A peer below v183 can publish the same legacy sample row as LIVE and as a
// tombstone in one payload: consolidation undo re-inserts the snapshot's
// dive_profiles rows verbatim while the old tombstones are still in its
// deletion_log. A row cannot be both present and deleted in one source
// snapshot, so the live row is that peer's current truth and the tombstone
// is a stale artifact -- the rule _applyRemotePayloadInner already applies
// to every other entity through its contradicted-key set.
//
// The legacy sample entities are inbound only, so they are absent from
// SyncData.toJson, which is what that set is built from. Without folding
// them back in, the tombstone wins: it is logged locally, and the merge
// then skips the live row (these entities carry no updatedAt, so there is
// no "newer than the deletion" escape) and the dive lands with no profile.
import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/core/services/sync/hlc.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';
import 'package:submersion/features/dive_log/data/repositories/profile_series_repository.dart';
import 'package:submersion/features/dive_log/domain/entities/dive.dart'
    as domain;

import '../../../helpers/fake_cloud_storage_provider.dart';
import '../../../helpers/test_database.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late FakeCloudStorageProvider cloud;

  setUp(() async {
    await setUpTestDatabase();
    cloud = FakeCloudStorageProvider();
  });

  tearDown(() => DatabaseService.instance.resetForTesting());

  SyncService buildService() => SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  );

  /// Publishes [dataJson] plus [deletions] as [peerId]'s single changeset and
  /// pulls it through the real merge path. Built from raw JSON because
  /// SyncPayload.toJson would drop the legacy keys on the way out.
  Future<void> pullPeerPayload(
    Map<String, dynamic> dataJson,
    Map<String, dynamic> deletions,
    String peerId,
  ) async {
    final payloadJson = <String, dynamic>{
      'version': syncFormatVersion,
      'exportedAt': 9000,
      'deviceId': peerId,
      'lastSyncTimestamp': null,
      'checksum': sha256.convert(utf8.encode(jsonEncode(dataJson))).toString(),
      'data': dataJson,
      'deletions': deletions,
      'uploadNonce': null,
      'epochId': null,
      'seq': 1,
      'baseSeq': null,
      'sinceHlc': null,
      'toHlc': null,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payloadJson)));
    final folder = await cloud.getOrCreateSyncFolder();
    await cloud.uploadFile(
      bytes,
      ChangesetLogLayout.changesetName(peerId, 1),
      folderId: folder,
    );
    await cloud.uploadFile(
      SyncManifest(
        deviceId: peerId,
        provider: cloud.providerId,
        headSeq: 1,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ).toBytes(),
      ChangesetLogLayout.manifestName(peerId),
      folderId: folder,
    );
    final result = await buildService().performSync();
    expect(result.status, isNot(SyncResultStatus.error));
  }

  Future<Map<String, dynamic>> peerDiveRow(String id, String peerId) async {
    await DiveRepository().createDive(
      domain.Dive(id: 'template', dateTime: DateTime(2026, 1, 1)),
    );
    return Map<String, dynamic>.from(
        (await SyncDataSerializer().fetchRecord('dives', 'template'))!,
      )
      ..['id'] = id
      ..['hlc'] = Hlc(9000, 0, peerId).toString();
  }

  test(
    'a legacy profile row live and tombstoned in one payload still lands',
    () async {
      final diveRow = await peerDiveRow('d-undone', 'peer-181');
      final profiles = [
        {
          'id': 'p1',
          'diveId': 'd-undone',
          'timestamp': 0,
          'depth': 0.0,
          'isPrimary': true,
        },
        {
          'id': 'p2',
          'diveId': 'd-undone',
          'timestamp': 60,
          'depth': 12.0,
          'isPrimary': true,
        },
      ];
      final data = SyncData(dives: [diveRow], diveProfiles: profiles);

      await pullPeerPayload(
        {...data.toJson(), 'diveProfiles': profiles},
        {
          'diveProfiles': [
            {'id': 'p1', 'deletedAt': 8000},
            {'id': 'p2', 'deletedAt': 8000},
          ],
        },
        'peer-181',
      );

      final series = await ProfileSeriesRepository().getSeriesForDive(
        'd-undone',
      );
      expect(
        series,
        hasLength(1),
        reason:
            'the live rows are the peer\'s current truth, not the tombstones',
      );
      expect(series.single.samples.map((s) => s.depth), [0.0, 12.0]);
    },
  );

  test('a tombstone the payload does not contradict still applies', () async {
    // The other half of the rule: a deletion for a row this payload does NOT
    // carry live is a real deletion, and must still be recorded so a later
    // payload carrying that row does not resurrect it.
    final diveRow = await peerDiveRow('d-deleted', 'peer-181');
    final profiles = [
      {
        'id': 'kept',
        'diveId': 'd-deleted',
        'timestamp': 0,
        'depth': 3.0,
        'isPrimary': true,
      },
    ];
    final data = SyncData(dives: [diveRow], diveProfiles: profiles);

    await pullPeerPayload(
      {...data.toJson(), 'diveProfiles': profiles},
      {
        'diveProfiles': [
          {'id': 'gone', 'deletedAt': 8000},
        ],
      },
      'peer-181',
    );

    final tombstones = await SyncRepository().getAllDeletions();
    expect(
      tombstones.where(
        (d) => d.entityType == 'diveProfiles' && d.recordId == 'gone',
      ),
      hasLength(1),
    );
    final series = await ProfileSeriesRepository().getSeriesForDive(
      'd-deleted',
    );
    expect(series.single.samples.single.depth, 3.0);
  });
}
