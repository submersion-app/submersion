import 'dart:convert';

import 'package:crypto/crypto.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/sync_service.dart';

import 'changeset_test_helpers.dart';
import 'fake_cloud_storage_provider.dart';

/// Publishes [data] as peer [peerId]'s base in [cloud], then runs one real
/// performSync on the current test database, so the rows go through the
/// same merge a real pull does.
Future<SyncResult> pullPeerPayload(
  FakeCloudStorageProvider cloud,
  SyncData data, {
  String peerId = 'peer-b',
}) async {
  await seedPeerBaseFromPayload(
    cloud,
    peerId,
    SyncPayload(
      version: syncFormatVersion,
      exportedAt: 9000,
      deviceId: peerId,
      checksum: sha256
          .convert(utf8.encode(jsonEncode(data.toJson())))
          .toString(),
      data: data,
      deletions: const {},
    ),
  );
  return SyncService(
    syncRepository: SyncRepository(),
    serializer: SyncDataSerializer(),
    cloudProvider: cloud,
  ).performSync();
}
