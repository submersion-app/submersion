import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_reader.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';
import 'package:submersion/features/dive_log/data/repositories/dive_repository_impl.dart';

import '../../../../helpers/changeset_test_helpers.dart';
import '../../../../helpers/test_database.dart';
import '../../../../helpers/mock_providers.dart';
import '../../../../support/fake_cloud_storage_provider.dart';

/// The newer-schema gate: peers publishing from a newer database schema are
/// held (not merged, cursor not advanced) until this device updates, and the
/// writer stamps every manifest with its schema version so peers can gate.
void main() {
  late FakeCloudStorageProvider provider;
  late ChangesetWriter writer;
  late ChangesetReader reader;
  late String folder;
  final applied = <SyncPayload>[];

  setUp(() async {
    await setUpTestDatabase();
    final db = DatabaseService.instance.database;
    final serializer = SyncDataSerializer();
    final codec = ChangesetCodec(serializer);
    writer = ChangesetWriter(
      serializer,
      codec,
      PublishStateStore(db),
      compactionByteRatio: 1000.0,
      compactionMaxChangesets: 1 << 30,
    );
    reader = ChangesetReader(codec, PeerCursorStore(db));
    provider = FakeCloudStorageProvider();
    folder = await provider.getOrCreateSyncFolder();
    applied.clear();
  });
  tearDown(() => tearDownTestDatabase());

  Future<void> spyApply(SyncPayload p) async => applied.add(p);

  Future<void> publishPeer(
    String peerId, {
    String? epochId,
    int? schemaVersionOverride,
  }) async {
    await writer.publish(
      provider: provider,
      deviceId: peerId,
      folderId: folder,
      deletions: const [],
      epochId: epochId,
    );
    if (schemaVersionOverride != null) {
      final manifestFile = (await provider.listFiles(
        folderId: folder,
        namePattern: ChangesetLogLayout.manifestName(peerId),
      )).single;
      final manifest =
          jsonDecode(utf8.decode(await provider.downloadFile(manifestFile.id)))
              as Map<String, dynamic>;
      manifest['schemaVersion'] = schemaVersionOverride;
      await provider.uploadFile(
        Uint8List.fromList(utf8.encode(jsonEncode(manifest))),
        manifestFile.name,
        folderId: folder,
      );
    }
  }

  Future<ChangesetReadResult> pull({String? currentEpochId}) => reader.pull(
    provider: provider,
    selfDeviceId: 'reader-x',
    folderId: folder,
    apply: spyApply,
    applyBaseFile: spyApplyBaseFile(applied),
    currentEpochId: currentEpochId,
  );

  test('published manifests are stamped with the schema version', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer('peer-1', epochId: 'epoch-A');

    final manifestFile = (await provider.listFiles(
      folderId: folder,
      namePattern: ChangesetLogLayout.manifestName('peer-1'),
    )).single;
    final manifest = SyncManifest.fromBytes(
      await provider.downloadFile(manifestFile.id),
    );

    expect(manifest.schemaVersion, AppDatabase.currentSchemaVersion);
  });

  test('holds a peer publishing from a newer schema', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer(
      'peer-1',
      epochId: 'epoch-A',
      schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
    );

    final result = await pull(currentEpochId: 'epoch-A');

    expect(result.peersProcessed, 0);
    expect(result.newerSchemaPeerDeviceIds, {'peer-1'});
    expect(applied, isEmpty);
  });

  test('a held peer is fully applied after this device updates', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    await publishPeer(
      'peer-1',
      epochId: 'epoch-A',
      schemaVersionOverride: AppDatabase.currentSchemaVersion + 1,
    );
    await pull(currentEpochId: 'epoch-A'); // held: cursor must not advance

    final result = await reader.pull(
      provider: provider,
      selfDeviceId: 'reader-x',
      folderId: folder,
      apply: spyApply,
      applyBaseFile: spyApplyBaseFile(applied),
      currentEpochId: 'epoch-A',
      localSchemaVersion: AppDatabase.currentSchemaVersion + 1,
    );

    expect(result.peersProcessed, 1);
    expect(result.newerSchemaPeerDeviceIds, isEmpty);
    expect(applied, isNotEmpty);
  });

  test('same-schema and legacy (unstamped) peers apply normally', () async {
    await DiveRepository().createDive(
      createTestDiveWithBottomTime(id: 'd1', diveNumber: 1),
    );
    // publishPeer without override stamps the current schema version.
    await publishPeer('peer-same', epochId: 'epoch-A');

    final result = await pull(currentEpochId: 'epoch-A');

    expect(result.peersProcessed, 1);
    expect(result.newerSchemaPeerDeviceIds, isEmpty);
  });
}
