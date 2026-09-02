import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/changeset_test_helpers.dart';
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
        applyBaseFile: spyApplyBaseFile(applied),
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
      applyBaseFile: spyApplyBaseFile(applied),
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

  test(
    'a peer whose read throws is reported and does not block other peers',
    () async {
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

      // A healthy peer publishes normally.
      final goodPeerId = await SyncRepository().getDeviceId();
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
      );
      await writer.publish(
        provider: provider,
        deviceId: goodPeerId,
        folderId: folder,
        deletions: const [],
      );

      // A broken peer: a valid manifest, but its changeset bytes are not
      // JSON, so decodeChangeset throws out of the per-peer read.
      const badPeerId = 'peer-broken';
      final manifest = SyncManifest(
        deviceId: badPeerId,
        deviceName: 'Broken Phone',
        provider: provider.providerId,
        headSeq: 1,
        updatedAt: 0,
      );
      await provider.uploadFile(
        manifest.toBytes(),
        ChangesetLogLayout.manifestName(badPeerId),
        folderId: folder,
      );
      await provider.uploadFile(
        Uint8List.fromList(utf8.encode('not json')),
        ChangesetLogLayout.changesetName(badPeerId, 1),
        folderId: folder,
      );

      final applied = <SyncPayload>[];
      final result = await reader.pull(
        provider: provider,
        selfDeviceId: 'reader-x',
        folderId: folder,
        apply: (p) async => applied.add(p),
        applyBaseFile: spyApplyBaseFile(applied),
      );

      expect(result.readFailedPeerDeviceIds, {
        badPeerId,
      }, reason: 'a per-peer read failure must be reported, not swallowed');
      expect(
        result.readFailedPeerNames[badPeerId],
        'Broken Phone',
        reason: 'the peer name from its manifest must reach the result',
      );

      final ids = applied
          .expand((p) => p.data.dives.map((d) => d['id']))
          .toSet();
      expect(
        ids,
        contains('d1'),
        reason: 'one bad peer must not block the healthy peers',
      );

      final badCursor = await PeerCursorStore(
        db,
      ).get(badPeerId, provider.providerId);
      expect(
        badCursor,
        isNull,
        reason:
            'the failed peer cursor must stay put so the next sync '
            'retries it',
      );
      final goodCursor = await PeerCursorStore(
        db,
      ).get(goodPeerId, provider.providerId);
      expect(goodCursor, isNotNull);
    },
  );

  test('a manifest naming a base with no part count is not applied', () async {
    await setUpTestDatabase();
    addTearDown(() => tearDownTestDatabase());
    final db = DatabaseService.instance.database;
    final codec = ChangesetCodec(SyncDataSerializer());
    final reader = ChangesetReader(codec, PeerCursorStore(db));
    final provider = FakeCloudStorageProvider();
    final folder = await provider.getOrCreateSyncFolder();

    // A manifest that claims a base (baseSeq + headSeq set) but carries no
    // basePartCount and uploads no base part files -- malformed / a publish in
    // flight. The reader must treat it as a transient gap, not an empty base.
    const peerId = 'peer-no-parts';
    final manifest = SyncManifest(
      deviceId: peerId,
      provider: provider.providerId,
      baseSeq: 1,
      headSeq: 1,
      updatedAt: 0,
    );
    await provider.uploadFile(
      manifest.toBytes(),
      ChangesetLogLayout.manifestName(peerId),
      folderId: folder,
    );

    final applied = <SyncPayload>[];
    await reader.pull(
      provider: provider,
      selfDeviceId: 'reader-x',
      folderId: folder,
      apply: (p) async => applied.add(p),
      applyBaseFile: spyApplyBaseFile(applied),
    );

    expect(
      applied,
      isEmpty,
      reason: 'a base with no parts must not be applied',
    );
    final cursor = await PeerCursorStore(db).get(peerId, provider.providerId);
    expect(
      cursor,
      isNull,
      reason: 'the cursor must not advance past a base that was never applied',
    );
  });

  test('a refused envelope keeps the progress made below it', () async {
    // An envelope the decorator rejects (an over-cap gzip payload from a
    // peer, or a tampered one) used to throw clear out of the changeset
    // loop to the per-peer catch, which skips the cursor upsert. Every
    // seq already applied was then re-downloaded and re-applied on every
    // later sync, and the cursor could never advance past the bad seq: a
    // livelock, not the transient stop the error type promises.
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
    final provider = _RefusingCloudStorageProvider();
    final folder = await provider.getOrCreateSyncFolder();

    final peerId = await SyncRepository().getDeviceId();
    // Base @1, then changesets @2 and @3.
    for (var i = 1; i <= 3; i++) {
      await DiveRepository().createDive(
        createTestDiveWithBottomTime(id: 'd$i', diveNumber: i),
      );
      await writer.publish(
        provider: provider,
        deviceId: peerId,
        folderId: folder,
        deletions: const [],
      );
    }
    provider.refuseName = ChangesetLogLayout.changesetName(peerId, 3);

    final applied = <SyncPayload>[];
    await reader.pull(
      provider: provider,
      selfDeviceId: 'reader-x',
      folderId: folder,
      apply: (p) async => applied.add(p),
      applyBaseFile: spyApplyBaseFile(applied),
    );

    final ids = applied.expand((p) => p.data.dives.map((d) => d['id'])).toSet();
    expect(ids, contains('d2'), reason: 'seq 2 was readable and applied');
    expect(
      ids,
      isNot(contains('d3')),
      reason: 'a refused seq must not be applied',
    );

    final cursor = await PeerCursorStore(db).get(peerId, provider.providerId);
    expect(
      cursor?.lastSeqApplied,
      2,
      reason:
          'the cursor must record the seqs already applied, so the next '
          'sync retries only the refused one',
    );
  });
}

/// Refuses one file the way the encrypting decorator refuses an envelope it
/// cannot open, so the reader sees a real [EnvelopeCorruptException] rather
/// than a hand-thrown stand-in.
class _RefusingCloudStorageProvider extends FakeCloudStorageProvider {
  String? refuseName;

  @override
  Future<Uint8List> downloadFile(String fileId) async {
    final name = fileId.substring(fileId.lastIndexOf('/') + 1);
    if (name == refuseName) {
      throw const EnvelopeCorruptException('Envelope payload rejected');
    }
    return super.downloadFile(fileId);
  }
}
