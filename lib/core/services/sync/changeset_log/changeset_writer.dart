import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_chunker.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

enum ChangesetWriteKind { base, changeset, noop }

class ChangesetWriteResult {
  const ChangesetWriteResult(this.kind, [this.seq]);
  final ChangesetWriteKind kind;
  final int? seq;
}

/// Publishes this device's local changes to its per-device changeset log.
///
/// The device's own cloud manifest is the authority: it is read first so the
/// sequence counter is recovered (never reused) even after local-state loss,
/// and a changeset reuses the manifest's existing base fields. The manifest is
/// rewritten last, as the commit point, after the data files it references.
class ChangesetWriter {
  ChangesetWriter(this._serializer, this._codec, this._publishState);

  final SyncDataSerializer _serializer;
  final ChangesetCodec _codec;
  final PublishStateStore _publishState;

  Future<ChangesetWriteResult> publish({
    required CloudStorageProvider provider,
    required String deviceId,
    required String folderId,
    required List<DeletionLogData> deletions,
    String? epochId,
    String? uploadNonce,
  }) async {
    final providerId = provider.providerId;
    final ownManifest = await _readOwnManifest(provider, folderId, deviceId);
    final state = await _publishState.get(providerId);

    final knownHeadSeq = _max(state?.headSeq ?? 0, ownManifest?.headSeq ?? 0);
    final hasBase = ownManifest?.baseSeq != null || state?.baseSeq != null;
    final watermark = ownManifest?.publishedHlcHigh ?? state?.publishedHlcHigh;

    final payload = await _serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: hasBase ? watermark : null,
      deletions: deletions,
      seq: knownHeadSeq + 1,
      epochId: epochId,
      uploadNonce: uploadNonce,
    );

    if (_isEmpty(payload)) {
      return const ChangesetWriteResult(ChangesetWriteKind.noop);
    }

    final newSeq = knownHeadSeq + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!hasBase) {
      final fullBytes = _codec.encodeChangeset(payload);
      final parts = _codec.encodeBaseParts(payload);
      for (var i = 0; i < parts.length; i++) {
        await provider.uploadFile(
          parts[i],
          ChangesetLogLayout.basePartName(deviceId, newSeq, i),
          folderId: folderId,
        );
      }
      final manifest = SyncManifest(
        deviceId: deviceId,
        provider: providerId,
        baseSeq: newSeq,
        basePartCount: parts.length,
        baseBytes: fullBytes.length,
        baseChecksum: BaseChunker.checksum(fullBytes),
        basePartChecksums: parts.map(BaseChunker.checksum).toList(),
        headSeq: newSeq,
        publishedHlcHigh: payload.toHlc,
        epochId: epochId,
        uploadNonce: uploadNonce,
        updatedAt: now,
      );
      await _writeManifest(provider, folderId, deviceId, manifest);
      await _publishState.upsert(
        LocalPublishStatesCompanion(
          provider: Value(providerId),
          baseSeq: Value(newSeq),
          basePartCount: Value(parts.length),
          baseBytes: Value(fullBytes.length),
          headSeq: Value(newSeq),
          publishedHlcHigh: Value(payload.toHlc),
          changesetBytesSinceBase: const Value(0),
          updatedAt: Value(now),
        ),
      );
      return ChangesetWriteResult(ChangesetWriteKind.base, newSeq);
    }

    // Changeset: reuse the base fields from the (authoritative) own manifest;
    // only headSeq / publishedHlcHigh advance.
    final bytes = _codec.encodeChangeset(payload);
    await provider.uploadFile(
      bytes,
      ChangesetLogLayout.changesetName(deviceId, newSeq),
      folderId: folderId,
    );
    final base = ownManifest!;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: base.baseSeq,
      basePartCount: base.basePartCount,
      baseBytes: base.baseBytes,
      baseChecksum: base.baseChecksum,
      basePartChecksums: base.basePartChecksums,
      headSeq: newSeq,
      publishedHlcHigh: payload.toHlc ?? base.publishedHlcHigh,
      epochId: epochId,
      uploadNonce: uploadNonce,
      updatedAt: now,
    );
    await _writeManifest(provider, folderId, deviceId, manifest);
    await _publishState.upsert(
      LocalPublishStatesCompanion(
        provider: Value(providerId),
        baseSeq: Value(base.baseSeq),
        basePartCount: Value(base.basePartCount),
        baseBytes: Value(base.baseBytes),
        headSeq: Value(newSeq),
        publishedHlcHigh: Value(payload.toHlc ?? base.publishedHlcHigh),
        changesetBytesSinceBase: Value(
          (state?.changesetBytesSinceBase ?? 0) + bytes.length,
        ),
        updatedAt: Value(now),
      ),
    );
    return ChangesetWriteResult(ChangesetWriteKind.changeset, newSeq);
  }

  Future<void> _writeManifest(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
    SyncManifest manifest,
  ) async {
    await provider.uploadFile(
      manifest.toBytes(),
      ChangesetLogLayout.manifestName(deviceId),
      folderId: folderId,
    );
  }

  Future<SyncManifest?> _readOwnManifest(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
  ) async {
    final name = ChangesetLogLayout.manifestName(deviceId);
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final matches = files.where((f) => f.name == name).toList();
    if (matches.isEmpty) return null;
    try {
      return SyncManifest.fromBytes(
        await provider.downloadFile(matches.first.id),
      );
    } catch (_) {
      return null;
    }
  }

  bool _isEmpty(SyncPayload payload) {
    final dataEmpty = payload.data.toJson().values.every(
      (v) => v is! List || v.isEmpty,
    );
    final deletionsEmpty = payload.deletions.values.every((l) => l.isEmpty);
    return dataEmpty && deletionsEmpty;
  }

  int _max(int a, int b) => a > b ? a : b;
}
