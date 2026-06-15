import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

void main() {
  test(
    'a corrupt changeset is not applied and the cursor stays below it',
    () async {
      await setUpTestDatabase();
      addTearDown(() => tearDownTestDatabase());
      final db = DatabaseService.instance.database;
      final serializer = SyncDataSerializer();
      final codec = ChangesetCodec(serializer);
      // Disable compaction so the changeset @2 survives to be corrupted.
      final writer = ChangesetWriter(
        serializer,
        codec,
        PublishStateStore(db),
        compactionByteRatio: 1000.0,
        compactionMaxChangesets: 1 << 30,
      );
      final reader = ChangesetReader(codec, PeerCursorStore(db));
      final provider = FakeCloudStorageProvider();
      final folder = await provider.getOrCreateSyncFolder();

      final peerId = await SyncRepository().getDeviceId();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await writer.publish(
        provider: provider,
        deviceId: peerId,
        folderId: folder,
        deletions: const [],
      );
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd2', diveNumber: 2),
      );
      await writer.publish(
        provider: provider,
        deviceId: peerId,
        folderId: folder,
        deletions: const [],
      );

      // Tamper the changeset @ seq 2: change the data without fixing the checksum.
      final csName = ChangesetLogLayout.changesetName(peerId, 2);
      final original = await provider.downloadFile('$folder/$csName');
      final tampered =
          jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
      (tampered['data'] as Map<String, dynamic>)['dives'] = [
        {'id': 'INJECTED'},
      ];
      await provider.uploadFile(
        Uint8List.fromList(utf8.encode(jsonEncode(tampered))),
        csName,
        folderId: folder,
      );

      final applied = <SyncPayload>[];
      await reader.pull(
        provider: provider,
        selfDeviceId: 'reader-x',
        folderId: folder,
        apply: (p) async => applied.add(p),
      );

      final ids = applied
          .expand((p) => p.data.dives.map((d) => d['id']))
          .toSet();
      expect(
        ids.contains('INJECTED'),
        isFalse,
        reason: 'a corrupt changeset must be rejected, not applied',
      );

      final cursor = await PeerCursorStore(db).get(peerId, provider.providerId);
      expect(
        cursor!.lastSeqApplied,
        lessThan(2),
        reason:
            'cursor must stay below the corrupt seq so a fixed sync retries',
      );
    },
  );

  test('a base part failing the manifest checksum is not applied', () async {
    await setUpTestDatabase();
    addTearDown(() => tearDownTestDatabase());
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    final codec = ChangesetCodec(serializer);
    final writer = ChangesetWriter(
      serializer,
      codec,
      PublishStateStore(db),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
    );
    final reader = ChangesetReader(codec, PeerCursorStore(db));
    final provider = FakeCloudStorageProvider();
    final folder = await provider.getOrCreateSyncFolder();

    final peerId = await SyncRepository().getDeviceId();
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await writer.publish(
      provider: provider,
      deviceId: peerId,
      folderId: folder,
      deletions: const [],
    );

    // Tamper the base part's DELETIONS only. The payload's data checksum is
    // computed over `data`, so it still matches and would let this base
    // through on its own -- but the bytes no longer match the manifest's
    // part/base checksums, which must reject it.
    final partName = ChangesetLogLayout.basePartName(peerId, 1, 0);
    final original = await provider.downloadFile('$folder/$partName');
    final tampered = jsonDecode(utf8.decode(original)) as Map<String, dynamic>;
    tampered['deletions'] = {
      'dives': [
        {'id': 'INJECTED-TOMBSTONE', 'deletedAt': 1},
      ],
    };
    await provider.uploadFile(
      Uint8List.fromList(utf8.encode(jsonEncode(tampered))),
      partName,
      folderId: folder,
    );

    final applied = <SyncPayload>[];
    await reader.pull(
      provider: provider,
      selfDeviceId: 'reader-x',
      folderId: folder,
      apply: (p) async => applied.add(p),
    );

    expect(
      applied,
      isEmpty,
      reason: 'a base failing the manifest checksum must not be applied',
    );
    final cursor = await PeerCursorStore(db).get(peerId, provider.providerId);
    expect(
      cursor,
      isNull,
      reason: 'the cursor must not advance past an unverified base',
    );
  });
}
