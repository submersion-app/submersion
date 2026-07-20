import 'dart:io';

import 'package:drift/drift.dart' show Value;

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_source.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/publish_state_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_liveness.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

enum ChangesetWriteKind { base, changeset, compacted, heartbeat, noop }

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
  ChangesetWriter(
    this._serializer,
    this._codec,
    this._publishState, {
    this.compactionByteRatio = 0.30,
    this.compactionMaxChangesets = 200,
    this.heartbeatMaxAgeMillis = SyncLiveness.heartbeatMaxAgeMillis,
  });

  final SyncDataSerializer _serializer;
  final ChangesetCodec _codec;
  final PublishStateStore _publishState;
  final double compactionByteRatio;
  final int compactionMaxChangesets;
  final int heartbeatMaxAgeMillis;

  Future<ChangesetWriteResult> publish({
    required CloudStorageProvider provider,
    required String deviceId,
    required String folderId,
    required List<DeletionLogData> deletions,
    String? epochId,
    String? uploadNonce,
    Map<String, String> appliedPeerHlc = const {},
  }) async {
    final providerId = provider.providerId;
    final ownManifest = await _readOwnManifest(provider, folderId, deviceId);
    final state = await _publishState.get(providerId);

    final knownHeadSeq = _max(state?.headSeq ?? 0, ownManifest?.headSeq ?? 0);
    // The cloud manifest is the authority for whether a base exists in the
    // cloud: a changeset can only be appended to a base we can actually read.
    // Local state alone is NOT enough -- if the manifest is missing (listing
    // lag on an eventually-consistent backend, or wiped by another device),
    // there is nothing to append to, so cold-start a fresh base. `state` still
    // recovers the seq counter (knownHeadSeq) so the new base never reuses a
    // number.
    final hasBase = ownManifest?.baseSeq != null;
    final watermark = ownManifest?.publishedHlcHigh ?? state?.publishedHlcHigh;
    // The post-adopt marker (a publish-state row with a null baseSeq): this
    // device's library IS the adopted epoch the peers already published, so
    // publishing its own base would redundantly re-upload the whole library --
    // and every peer would have to re-download it just to reach the deltas
    // behind it (the post-adopt "changes don't show up" unreliability). While
    // the marker holds, publish changesets with NO base: a reader cold-starts
    // a base-less manifest by applying changesets from seq 1 (the adopted
    // content itself comes from the epoch peers' bases). Compaction
    // eventually folds the log into a real base, clearing the marker.
    //
    // A null watermark disables this mode: with nothing to delta against,
    // exportChangeset would materialize the ENTIRE library in memory (the
    // exact full-upload/OOM this path avoids, #358). maxRowHlc() is null at
    // adopt for an empty library (the base below no-ops) or one whose rows
    // all predate HLC stamping (one streamed base publish, safely bounded).
    final adoptedNoBase =
        !hasBase && state != null && state.baseSeq == null && watermark != null;

    final newSeq = knownHeadSeq + 1;
    final now = DateTime.now().millisecondsSinceEpoch;

    if (!hasBase && !adoptedNoBase) {
      // Stream the base to a temp file and slice-upload it, so a large library
      // is never materialized in RAM (#358 write side). Do NOT call
      // exportChangeset(null) here -- that is the OOM path.
      final base = await _serializer.exportBaseToTempFile(
        deviceId: deviceId,
        deletions: deletions,
        epochId: epochId,
        uploadNonce: uploadNonce,
        seq: newSeq,
      );
      try {
        if (base.rowCount == 0 && deletions.isEmpty) {
          return const ChangesetWriteResult(ChangesetWriteKind.noop);
        }
        final upload = await BasePartFileSource(base.path).uploadAll(
          (i, bytes) => provider.uploadFile(
            bytes,
            ChangesetLogLayout.basePartName(deviceId, newSeq, i),
            folderId: folderId,
          ),
        );
        final manifest = SyncManifest(
          deviceId: deviceId,
          provider: providerId,
          baseSeq: newSeq,
          basePartCount: upload.partCount,
          baseBytes: base.byteLength,
          baseChecksum: upload.wholeChecksum,
          basePartChecksums: upload.partChecksums,
          headSeq: newSeq,
          publishedHlcHigh: base.toHlc,
          epochId: epochId,
          uploadNonce: uploadNonce,
          appliedPeerHlc: appliedPeerHlc,
          updatedAt: now,
        );
        await _writeManifest(provider, folderId, deviceId, manifest);
        await _publishState.upsert(
          LocalPublishStatesCompanion(
            provider: Value(providerId),
            baseSeq: Value(newSeq),
            basePartCount: Value(upload.partCount),
            baseBytes: Value(base.byteLength),
            headSeq: Value(newSeq),
            publishedHlcHigh: Value(base.toHlc),
            changesetBytesSinceBase: const Value(0),
            updatedAt: Value(now),
          ),
        );
        return ChangesetWriteResult(ChangesetWriteKind.base, newSeq);
      } finally {
        try {
          await File(base.path).delete();
        } catch (_) {}
      }
    }

    // Changeset: reuse the base fields from the (authoritative) own manifest;
    // only headSeq / publishedHlcHigh advance. In the adopted mode there is no
    // manifest yet (or a base-less one), so the base fields stay null and the
    // watermark comes from the publish state (the adopted library's max HLC,
    // recorded at adopt). The incremental delta stays in memory (small); only
    // the base path above is streamed (#358).
    final payload = await _serializer.exportChangeset(
      deviceId: deviceId,
      hlcWatermark: watermark,
      deletions: deletions,
      seq: newSeq,
      epochId: epochId,
      uploadNonce: uploadNonce,
    );
    if (_isEmpty(payload)) {
      // Nothing to publish -- but a manifest that goes stale reads as a dead
      // device to peers (retirement) and its acks stop advancing tombstone
      // GC. Rewrite it (contents unchanged, fresh updatedAt + acks) once it
      // ages past the threshold. The nonce is preserved: a heartbeat is not
      // an upload event and must not disturb twin detection.
      if (ownManifest != null &&
          now - ownManifest.updatedAt > heartbeatMaxAgeMillis) {
        final beat = SyncManifest(
          deviceId: ownManifest.deviceId,
          provider: ownManifest.provider,
          baseSeq: ownManifest.baseSeq,
          basePartCount: ownManifest.basePartCount,
          baseBytes: ownManifest.baseBytes,
          baseChecksum: ownManifest.baseChecksum,
          basePartChecksums: ownManifest.basePartChecksums,
          headSeq: ownManifest.headSeq,
          publishedHlcHigh: ownManifest.publishedHlcHigh,
          epochId: ownManifest.epochId,
          uploadNonce: ownManifest.uploadNonce,
          appliedPeerHlc: appliedPeerHlc,
          updatedAt: now,
        );
        await _writeManifest(provider, folderId, deviceId, beat);
        return ChangesetWriteResult(
          ChangesetWriteKind.heartbeat,
          ownManifest.headSeq,
        );
      }
      return const ChangesetWriteResult(ChangesetWriteKind.noop);
    }
    final bytes = _codec.encodeChangeset(payload);
    await provider.uploadFile(
      bytes,
      ChangesetLogLayout.changesetName(deviceId, newSeq),
      folderId: folderId,
    );
    final publishedHigh = payload.toHlc ?? watermark;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: ownManifest?.baseSeq,
      basePartCount: ownManifest?.basePartCount,
      baseBytes: ownManifest?.baseBytes,
      baseChecksum: ownManifest?.baseChecksum,
      basePartChecksums: ownManifest?.basePartChecksums ?? const [],
      headSeq: newSeq,
      publishedHlcHigh: publishedHigh,
      epochId: epochId,
      uploadNonce: uploadNonce,
      appliedPeerHlc: appliedPeerHlc,
      updatedAt: now,
    );
    await _writeManifest(provider, folderId, deviceId, manifest);
    await _publishState.upsert(
      LocalPublishStatesCompanion(
        provider: Value(providerId),
        baseSeq: Value(ownManifest?.baseSeq),
        basePartCount: Value(ownManifest?.basePartCount),
        baseBytes: Value(ownManifest?.baseBytes),
        headSeq: Value(newSeq),
        publishedHlcHigh: Value(publishedHigh),
        changesetBytesSinceBase: Value(
          (state?.changesetBytesSinceBase ?? 0) + bytes.length,
        ),
        updatedAt: Value(now),
      ),
    );

    final bytesSinceBase = (state?.changesetBytesSinceBase ?? 0) + bytes.length;
    final baseBytes = ownManifest?.baseBytes ?? 0;
    // A base-less (post-adopt) log counts changesets from seq 0 so it still
    // trips the count threshold and folds into a real base -- the deferred
    // base finally gets published once, amortized, instead of never.
    final tripped =
        (newSeq - (ownManifest?.baseSeq ?? 0)) >= compactionMaxChangesets ||
        (baseBytes > 0 && bytesSinceBase >= compactionByteRatio * baseBytes);
    if (tripped) {
      final compSeq = await _compact(
        provider: provider,
        deviceId: deviceId,
        folderId: folderId,
        providerId: providerId,
        afterSeq: newSeq,
        deletions: deletions,
        epochId: epochId,
        uploadNonce: uploadNonce,
        appliedPeerHlc: appliedPeerHlc,
      );
      return ChangesetWriteResult(ChangesetWriteKind.compacted, compSeq);
    }
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

  /// Rewrite a fresh full base at [afterSeq] + 1, repoint the manifest, reset
  /// publish state, and prune superseded files. Pruning is inline with no grace
  /// window: this intentionally diverges from the spec's 14-day grace, which
  /// only existed to spare an in-flight reader a re-fetch. It is safe because a
  /// reader mid-fetch of now-pruned files cold-starts from the new base (their
  /// superset) on the next sync -- self-healing, with no data loss. A time-based
  /// grace remains a possible future optimization to avoid that single re-fetch.
  Future<int> _compact({
    required CloudStorageProvider provider,
    required String deviceId,
    required String folderId,
    required String providerId,
    required int afterSeq,
    required List<DeletionLogData> deletions,
    required Map<String, String> appliedPeerHlc,
    String? epochId,
    String? uploadNonce,
  }) async {
    // The fresh base must carry the full deletion log: a peer that still holds
    // a since-deleted record and cold-starts from this base (its prior
    // changesets pruned) would otherwise never see the tombstone and resurrect
    // the row. Mirrors the first base, which also exports with deletions.
    // Stream the fresh base to a temp file and slice-upload it (bounded memory,
    // #358), mirroring publish()'s base path. The base still carries the full
    // deletion log (see above).
    final compSeq = afterSeq + 1;
    final base = await _serializer.exportBaseToTempFile(
      deviceId: deviceId,
      deletions: deletions,
      epochId: epochId,
      uploadNonce: uploadNonce,
      seq: compSeq,
    );
    final BasePartUploadResult upload;
    try {
      upload = await BasePartFileSource(base.path).uploadAll(
        (i, bytes) => provider.uploadFile(
          bytes,
          ChangesetLogLayout.basePartName(deviceId, compSeq, i),
          folderId: folderId,
        ),
      );
    } finally {
      try {
        await File(base.path).delete();
      } catch (_) {}
    }
    final now = DateTime.now().millisecondsSinceEpoch;
    final manifest = SyncManifest(
      deviceId: deviceId,
      provider: providerId,
      baseSeq: compSeq,
      basePartCount: upload.partCount,
      baseBytes: base.byteLength,
      baseChecksum: upload.wholeChecksum,
      basePartChecksums: upload.partChecksums,
      headSeq: compSeq,
      publishedHlcHigh: base.toHlc,
      epochId: epochId,
      uploadNonce: uploadNonce,
      appliedPeerHlc: appliedPeerHlc,
      updatedAt: now,
    );
    await _writeManifest(provider, folderId, deviceId, manifest);
    await _publishState.upsert(
      LocalPublishStatesCompanion(
        provider: Value(providerId),
        baseSeq: Value(compSeq),
        basePartCount: Value(upload.partCount),
        baseBytes: Value(base.byteLength),
        headSeq: Value(compSeq),
        publishedHlcHigh: Value(base.toHlc),
        changesetBytesSinceBase: const Value(0),
        updatedAt: Value(now),
      ),
    );
    await _pruneSupersededBelow(provider, folderId, deviceId, compSeq);
    return compSeq;
  }

  /// Best-effort: pruning is a post-commit optimization -- the fresh base and
  /// manifest are already durable, so a transient list/delete failure must
  /// never fail the publish. Superseded files are harmless (the base is their
  /// superset) and a later sync re-runs this idempotent sweep.
  Future<void> _pruneSupersededBelow(
    CloudStorageProvider provider,
    String folderId,
    String deviceId,
    int keepBaseSeq,
  ) async {
    try {
      final files = await provider.listFiles(
        folderId: folderId,
        namePattern: ChangesetLogLayout.prefix,
      );
      for (final f in files) {
        if (ChangesetLogLayout.deviceIdOf(f.name) != deviceId) continue;
        final cs = ChangesetLogLayout.changesetSeqOf(f.name);
        final bp = ChangesetLogLayout.basePartOf(f.name);
        final supersededCs = cs != null && cs < keepBaseSeq;
        final supersededBase = bp != null && bp.baseSeq != keepBaseSeq;
        if (supersededCs || supersededBase) {
          try {
            await provider.deleteFile(f.id);
          } catch (_) {
            // Leave this file; the next compaction's sweep retries it.
          }
        }
      }
    } catch (_) {
      // Listing failed -- skip pruning this round. The new base/manifest are
      // already committed; the next sync re-runs this idempotent sweep.
    }
  }
}
