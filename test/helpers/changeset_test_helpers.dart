import 'dart:typed_data';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_writer.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

import 'test_database.dart';

/// Test harness for the per-device changeset-log transport (ssv1.* files).
///
/// Replaces two retired full-file patterns:
/// - `cloud.seedFile('submersion_sync_<peer>.json', bytes)` -> [seedPeerLog]
///   (publish real data as a peer) or [seedPeerManifest] (just make a peer
///   discoverable).
/// - `serializer.deserializePayload(cloud.syncFileBytes())` -> [cloudBasePayload]
///   (read our own exported base back) / [hasPublishedLog] / [ownManifest].

/// A writer with compaction disabled: a single changeset can exceed 30% of a
/// near-empty test base, so the count/byte triggers must be pushed out of
/// reach or tiny-DB tests would compact unexpectedly.
ChangesetWriter _testWriter() {
  final db = DatabaseService.instance.database;
  final serializer = SyncDataSerializer();
  return ChangesetWriter(
    serializer,
    ChangesetCodec(serializer),
    PublishStateStore(db),
    compactionByteRatio: 1000.0,
    compactionMaxChangesets: 1 << 30,
  );
}

/// Publish the CURRENT database contents into [cloud] as peer [peerId]'s
/// changeset log, then wipe and recreate the local DB so the caller continues
/// as a fresh device that sees the peer's files. Mirrors the convergence
/// test's publish-then-swap pattern; the cloud keeps the peer's ssv1.* files
/// across the reset (cloud is independent of the DB).
///
/// Usage: create the peer's data, call [seedPeerLog], then create the LOCAL
/// data (the reset clears anything created before the call).
Future<void> seedPeerLog(
  CloudStorageProvider cloud,
  String peerId, {
  String? epochId,
  String? uploadNonce,
}) async {
  final folder = await cloud.getOrCreateSyncFolder();
  final deletions = await SyncRepository().getAllDeletions();
  await _testWriter().publish(
    provider: cloud,
    deviceId: peerId,
    folderId: folder,
    deletions: deletions,
    epochId: epochId,
    uploadNonce: uploadNonce,
  );
  DatabaseService.instance.resetForTesting();
  await setUpTestDatabase();
}

/// Publish the current DB as [deviceId]'s OWN log WITHOUT resetting the DB.
/// Use to set up a pre-existing own manifest -- e.g. injecting a foreign
/// [uploadNonce] to drive the twin-identity split.
Future<void> publishOwnLog(
  CloudStorageProvider cloud,
  String deviceId, {
  String? epochId,
  String? uploadNonce,
}) async {
  final folder = await cloud.getOrCreateSyncFolder();
  final deletions = await SyncRepository().getAllDeletions();
  await _testWriter().publish(
    provider: cloud,
    deviceId: deviceId,
    folderId: folder,
    deletions: deletions,
    epochId: epochId,
    uploadNonce: uploadNonce,
  );
}

/// Write a minimal manifest for [peerId] directly, modelling a peer whose log
/// merely EXISTS without publishing real data. Use when a test only needs a
/// peer to be discoverable (e.g. first-contact peer counting), not applied.
Future<void> seedPeerManifest(
  CloudStorageProvider cloud,
  String peerId, {
  String? epochId,
  String? uploadNonce,
}) async {
  final folder = await cloud.getOrCreateSyncFolder();
  final manifest = SyncManifest(
    deviceId: peerId,
    provider: cloud.providerId,
    baseSeq: 1,
    basePartCount: 0,
    baseBytes: 0,
    headSeq: 1,
    epochId: epochId,
    uploadNonce: uploadNonce,
    updatedAt: 0,
  );
  await cloud.uploadFile(
    manifest.toBytes(),
    ChangesetLogLayout.manifestName(peerId),
    folderId: folder,
  );
}

/// Write [peerId]'s log directly from a pre-built (possibly hand-corrupted)
/// [payload], with manifest checksums consistent with the bytes so it passes
/// transport-level checksum validation. Models a peer whose data is well-formed
/// on the wire but unapplyable (e.g. a non-nullable field carrying a bad value),
/// so the failure surfaces at apply time rather than as a transport error.
Future<void> seedPeerBaseFromPayload(
  CloudStorageProvider cloud,
  String peerId,
  SyncPayload payload, {
  String? epochId,
  String? uploadNonce,
}) async {
  final serializer = SyncDataSerializer();
  final codec = ChangesetCodec(serializer);
  final folder = await cloud.getOrCreateSyncFolder();
  final fullBytes = codec.encodeChangeset(payload);
  final parts = codec.encodeBaseParts(payload);
  for (var i = 0; i < parts.length; i++) {
    await cloud.uploadFile(
      parts[i],
      ChangesetLogLayout.basePartName(peerId, 1, i),
      folderId: folder,
    );
  }
  final manifest = SyncManifest(
    deviceId: peerId,
    provider: cloud.providerId,
    baseSeq: 1,
    basePartCount: parts.length,
    baseBytes: fullBytes.length,
    baseChecksum: BaseChunker.checksum(fullBytes),
    basePartChecksums: parts.map(BaseChunker.checksum).toList(),
    headSeq: 1,
    publishedHlcHigh: payload.toHlc,
    epochId: epochId,
    uploadNonce: uploadNonce,
    updatedAt: 0,
  );
  await cloud.uploadFile(
    manifest.toBytes(),
    ChangesetLogLayout.manifestName(peerId),
    folderId: folder,
  );
}

/// Read [deviceId]'s own base payload back from its log (manifest -> base
/// parts -> decoded [SyncPayload]), or null if it has no base. Replaces the old
/// `deserializePayload(cloud.syncFileBytes())` for export-shape assertions.
Future<SyncPayload?> cloudBasePayload(
  CloudStorageProvider cloud,
  String deviceId,
) async {
  final folder = await cloud.getOrCreateSyncFolder();
  final manifest = await _readManifest(cloud, folder, deviceId);
  final baseSeq = manifest?.baseSeq;
  if (manifest == null || baseSeq == null) return null;
  final files = await cloud.listFiles(
    folderId: folder,
    namePattern: ChangesetLogLayout.prefix,
  );
  final byName = {for (final f in files) f.name: f};
  final parts = <Uint8List>[];
  for (var i = 0; i < (manifest.basePartCount ?? 0); i++) {
    final pf = byName[ChangesetLogLayout.basePartName(deviceId, baseSeq, i)];
    if (pf == null) return null;
    parts.add(await cloud.downloadFile(pf.id));
  }
  if (parts.isEmpty) return null;
  final serializer = SyncDataSerializer();
  return ChangesetCodec(serializer).decodeBaseParts(parts);
}

/// True if [deviceId] has published a manifest (its log exists in [cloud]).
Future<bool> hasPublishedLog(
  CloudStorageProvider cloud,
  String deviceId,
) async {
  final folder = await cloud.getOrCreateSyncFolder();
  return (await _readManifest(cloud, folder, deviceId)) != null;
}

/// This device's own changeset manifest, or null.
Future<SyncManifest?> ownManifest(
  CloudStorageProvider cloud,
  String deviceId,
) async {
  final folder = await cloud.getOrCreateSyncFolder();
  return _readManifest(cloud, folder, deviceId);
}

Future<SyncManifest?> _readManifest(
  CloudStorageProvider cloud,
  String folder,
  String deviceId,
) async {
  final name = ChangesetLogLayout.manifestName(deviceId);
  final files = await cloud.listFiles(
    folderId: folder,
    namePattern: ChangesetLogLayout.prefix,
  );
  final match = files.where((f) => f.name == name).toList();
  if (match.isEmpty) return null;
  try {
    return SyncManifest.fromBytes(await cloud.downloadFile(match.first.id));
  } catch (_) {
    return null;
  }
}
