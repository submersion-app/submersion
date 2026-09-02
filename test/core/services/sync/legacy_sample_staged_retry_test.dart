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

/// Staged legacy rows outlive the apply that could not place them: a row
/// whose dive has not arrived yet is kept, and the shim documents that "the
/// next apply in this session calls this again and retries it".
///
/// It only does if something asks it to. The pack was gated on the payload
/// in hand carrying legacy rows, so the dive's own arrival, in a payload
/// with none, went by without a retry and the rows died with the TEMP table.
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

  /// Publishes [dataJson] as [peerId]'s changeset [seq] and syncs.
  Future<void> pullPeerChangeset(
    Map<String, dynamic> dataJson,
    String peerId,
    int seq,
  ) async {
    final payloadJson = <String, dynamic>{
      'version': syncFormatVersion,
      'exportedAt': 9000 + seq,
      'deviceId': peerId,
      'lastSyncTimestamp': null,
      'checksum': sha256.convert(utf8.encode(jsonEncode(dataJson))).toString(),
      'data': dataJson,
      'deletions': <String, dynamic>{},
      'uploadNonce': null,
      'epochId': null,
      'seq': seq,
      'baseSeq': null,
      'sinceHlc': null,
      'toHlc': null,
    };
    final bytes = Uint8List.fromList(utf8.encode(jsonEncode(payloadJson)));
    final folder = await cloud.getOrCreateSyncFolder();
    await cloud.uploadFile(
      bytes,
      ChangesetLogLayout.changesetName(peerId, seq),
      folderId: folder,
    );
    await cloud.uploadFile(
      SyncManifest(
        deviceId: peerId,
        provider: cloud.providerId,
        headSeq: seq,
        updatedAt: DateTime.now().millisecondsSinceEpoch,
      ).toBytes(),
      ChangesetLogLayout.manifestName(peerId),
      folderId: folder,
    );
    final result = await buildService().performSync();
    expect(result.status, isNot(SyncResultStatus.error));
  }

  test(
    'staged rows are retried when their dive arrives without them',
    () async {
      // A template row to shape the peer's dive from.
      await DiveRepository().createDive(
        domain.Dive(id: 'template', dateTime: DateTime(2026, 1, 1)),
      );
      final diveRow =
          Map<String, dynamic>.from(
              (await SyncDataSerializer().fetchRecord('dives', 'template'))!,
            )
            ..['id'] = 'd-late'
            ..['hlc'] = const Hlc(9000, 0, 'peer-181').toString();

      // 1: the samples arrive before their dive, so nothing can be packed and
      // the shim keeps them staged.
      final profiles = [
        {
          'id': 'p1',
          'diveId': 'd-late',
          'timestamp': 0,
          'depth': 0.0,
          'isPrimary': true,
        },
        {
          'id': 'p2',
          'diveId': 'd-late',
          'timestamp': 60,
          'depth': 9.0,
          'isPrimary': true,
        },
      ];
      await pullPeerChangeset(
        {...const SyncData().toJson(), 'diveProfiles': profiles},
        'peer-181',
        1,
      );
      expect(
        await ProfileSeriesRepository().getSeriesForDive('d-late'),
        isEmpty,
      );

      // 2: the dive itself, carrying no legacy rows of its own.
      await pullPeerChangeset(
        SyncData(dives: [diveRow]).toJson(),
        'peer-181',
        2,
      );

      final series = await ProfileSeriesRepository().getSeriesForDive('d-late');
      expect(
        series,
        hasLength(1),
        reason: 'the staged rows are the only copy the peer will ever send',
      );
      expect(series.single.samples.map((s) => s.depth), [0.0, 9.0]);
    },
  );

  test('a payload with nothing staged does not pack', () async {
    // The common case once every peer has upgraded: no staging tables, no
    // legacy rows, and the gate must stay shut rather than probing on every
    // apply for a shim that will never fire again.
    await DiveRepository().createDive(
      domain.Dive(id: 'template2', dateTime: DateTime(2026, 1, 2)),
    );
    final diveRow =
        Map<String, dynamic>.from(
            (await SyncDataSerializer().fetchRecord('dives', 'template2'))!,
          )
          ..['id'] = 'd-plain'
          ..['hlc'] = const Hlc(9000, 0, 'peer-183').toString();

    await pullPeerChangeset(SyncData(dives: [diveRow]).toJson(), 'peer-183', 1);

    expect(
      await ProfileSeriesRepository().getSeriesForDive('d-plain'),
      isEmpty,
    );
  });
}
