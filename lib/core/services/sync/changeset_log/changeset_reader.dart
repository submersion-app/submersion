import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/sync_data_serializer.dart';
import 'package:submersion/core/services/sync/changeset_log/base_part_file_sink.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_codec.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/peer_cursor_store.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// Applies one decoded payload (base or changeset). The real implementation is
/// SyncService._applyRemotePayload (HLC LWW + tombstones + FK repair), injected
/// so the merge stays the single source of truth.
typedef ApplyPayload = Future<void> Function(SyncPayload payload);

/// Applies a base that has been streamed to a local temp [filePath]. The real
/// implementation streams the file through the merge in bounded memory; see
/// SyncService._applyRemoteBaseFile.
typedef ApplyBaseFile =
    Future<void> Function(String filePath, SyncManifest manifest);

class ChangesetReadResult {
  const ChangesetReadResult({
    required this.peersProcessed,
    required this.payloadsApplied,
  });
  final int peersProcessed;
  final int payloadsApplied;
}

/// Consumes peers' changeset logs: discovers peers, decides per-peer what to
/// fetch against [PeerCursorStore], applies in seq order via [ApplyPayload],
/// and advances the cursor. Stops at the first missing file (transient gap)
/// and retries next sync; application is idempotent so re-reads are safe.
class ChangesetReader {
  ChangesetReader(this._codec, this._peerCursors, {BasePartFileSink? baseSink})
    : _baseSink = baseSink ?? BasePartFileSink();

  final ChangesetCodec _codec;
  final PeerCursorStore _peerCursors;
  final BasePartFileSink _baseSink;

  Future<ChangesetReadResult> pull({
    required CloudStorageProvider provider,
    required String selfDeviceId,
    required String folderId,
    required ApplyPayload apply,
    required ApplyBaseFile applyBaseFile,
    String? currentEpochId,
  }) async {
    final providerId = provider.providerId;
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    final byName = {for (final f in files) f.name: f};
    final peerIds = ChangesetLogLayout.peerDeviceIds(
      files.map((f) => f.name),
      selfDeviceId,
    );

    var peersProcessed = 0;
    var payloadsApplied = 0;

    for (final peerId in peerIds) {
      try {
        final manifestFile = byName[ChangesetLogLayout.manifestName(peerId)];
        if (manifestFile == null) continue; // files but no manifest yet
        final manifest = SyncManifest.fromBytes(
          await provider.downloadFile(manifestFile.id),
        );

        // Stale-epoch filter: once this device is on a library epoch, a peer
        // stamped with a different epoch (or unstamped) is inert -- applying it
        // would leak a replaced-away library back in. Mirrors performSync's
        // per-file filter. Null currentEpochId is the pre-epoch world: no
        // filtering, apply every peer.
        if (currentEpochId != null && manifest.epochId != currentEpochId) {
          continue;
        }
        peersProcessed++;

        final cursor = await _peerCursors.get(peerId, providerId);
        final lastApplied = cursor?.lastSeqApplied ?? 0;
        if (lastApplied >= manifest.headSeq) continue; // up to date

        var appliedThrough = lastApplied;
        var baseSeqApplied = cursor?.baseSeqApplied;

        // Cold-start, or lapped by the peer's compaction: adopt the base.
        final baseSeq = manifest.baseSeq;
        if (baseSeq != null && lastApplied < baseSeq) {
          final path = await _fetchBaseToFile(
            provider,
            peerId,
            manifest,
            byName,
          );
          if (path == null) {
            continue; // missing or corrupt base -> transient, retry next sync
          }
          try {
            await applyBaseFile(path, manifest);
          } finally {
            await _baseSink.deleteQuietly(path);
          }
          payloadsApplied++;
          appliedThrough = baseSeq;
          baseSeqApplied = baseSeq;
        }

        // Changesets (appliedThrough+1 .. headSeq], stopping at the first gap.
        for (var seq = appliedThrough + 1; seq <= manifest.headSeq; seq++) {
          final csFile = byName[ChangesetLogLayout.changesetName(peerId, seq)];
          if (csFile == null) break; // gap -> apply what we have, retry later
          final cs = _codec.decodeChangeset(
            await provider.downloadFile(csFile.id),
          );
          if (!_codec.serializer.validateChecksum(cs)) {
            break; // corrupt changeset -> stop; a fixed sync retries from here
          }
          await apply(cs);
          payloadsApplied++;
          appliedThrough = seq;
        }

        // Advance only forward, after applying, so an interrupted apply
        // re-pulls next time rather than skipping a seq.
        if (appliedThrough > lastApplied) {
          await _peerCursors.upsert(
            peerDeviceId: peerId,
            provider: providerId,
            baseSeqApplied: baseSeqApplied,
            lastSeqApplied: appliedThrough,
          );
        }
      } catch (_) {
        // One bad peer must not block the others; its cursor stays put so the
        // next sync retries it.
        continue;
      }
    }

    return ChangesetReadResult(
      peersProcessed: peersProcessed,
      payloadsApplied: payloadsApplied,
    );
  }

  /// Streams the peer's base parts into a single temp file, verifying each
  /// part and the whole-file checksum as bytes land (never holding the base in
  /// memory). Returns the temp file path, or null if a part is missing or any
  /// checksum fails (transient -> retry next sync). The byte-level checksums
  /// are independent of -- and stronger than -- the decoded payload's data
  /// checksum, which ignores headers and deletions.
  Future<String?> _fetchBaseToFile(
    CloudStorageProvider provider,
    String peerId,
    SyncManifest manifest,
    Map<String, CloudFileInfo> byName,
  ) {
    final baseSeq = manifest.baseSeq!;
    final partCount = manifest.basePartCount ?? 0;
    // A manifest that names a base (baseSeq set) but no parts is malformed --
    // a real base always has at least one part. Treat it as a transient gap
    // (publish in flight / truncated manifest) so we don't assemble an empty
    // file and advance the cursor past a base we never applied.
    if (partCount <= 0) return Future<String?>.value(null);
    return _baseSink.assemble(
      name: 'ssv1_${peerId}_$baseSeq',
      partCount: partCount,
      wholeChecksum: manifest.baseChecksum,
      partChecksums: manifest.basePartChecksums,
      downloadPart: (i) async {
        final pf = byName[ChangesetLogLayout.basePartName(peerId, baseSeq, i)];
        if (pf == null) return null;
        return provider.downloadFile(pf.id);
      },
    );
  }
}
