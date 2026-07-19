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
    this.peerManifests = const [],
    this.retiredPeerIds = const {},
    this.retiredPeerHasFiles = false,
  });
  final int peersProcessed;
  final int payloadsApplied;

  /// Every non-retired peer manifest seen this pull (including stale-epoch
  /// ones, which stay inert for merging but still block/inform tombstone GC).
  final List<SyncManifest> peerManifests;
  final Set<String> retiredPeerIds;

  /// True when a retired peer still has non-marker files in the bucket (a
  /// partial retirement) -- tells the sweeper to retry the deletion.
  final bool retiredPeerHasFiles;
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
    List<CloudFileInfo>? preListedFiles,
  }) async {
    final providerId = provider.providerId;
    // [preListedFiles] lets the caller reuse a listing it just made (the
    // retirement-fence check lists the same folder immediately before this
    // pull), saving a round-trip on high-latency backends. Safe because
    // nothing mutates the folder between that listing and this pull, and
    // every consumer is already tolerant of a slightly stale view (a missing
    // file reads as a transient gap and retries next sync).
    final files =
        preListedFiles ??
        await provider.listFiles(
          folderId: folderId,
          namePattern: ChangesetLogLayout.prefix,
        );
    final byName = {for (final f in files) f.name: f};
    final peerIds = ChangesetLogLayout.peerDeviceIds(
      files.map((f) => f.name),
      selfDeviceId,
    );
    final retiredPeerIds = <String>{
      for (final f in files)
        if (ChangesetLogLayout.isRetiredMarker(f.name) &&
            ChangesetLogLayout.deviceIdOf(f.name) != null &&
            ChangesetLogLayout.deviceIdOf(f.name) != selfDeviceId)
          ChangesetLogLayout.deviceIdOf(f.name)!,
    };
    final retiredPeerHasFiles = files.any(
      (f) =>
          !ChangesetLogLayout.isRetiredMarker(f.name) &&
          retiredPeerIds.contains(ChangesetLogLayout.deviceIdOf(f.name)),
    );
    final peerManifests = <SyncManifest>[];

    var peersProcessed = 0;
    var payloadsApplied = 0;

    for (final peerId in peerIds) {
      try {
        // A retired peer's files are being deleted; never merge from them and
        // never advance a cursor against them.
        if (retiredPeerIds.contains(peerId)) continue;
        final manifestFile = byName[ChangesetLogLayout.manifestName(peerId)];
        if (manifestFile == null) continue; // files but no manifest yet
        final manifest = SyncManifest.fromBytes(
          await provider.downloadFile(manifestFile.id),
        );
        peerManifests.add(manifest);

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
        var appliedHlc = cursor?.appliedHlcHigh;

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
          // The manifest's publishedHlcHigh describes headSeq; it equals the
          // base's own high watermark only when the base IS the head. Never
          // over-claim an ack -- tombstone GC relies on it.
          if (baseSeq == manifest.headSeq) {
            appliedHlc = _maxHlc(appliedHlc, manifest.publishedHlcHigh);
          }
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
          appliedHlc = _maxHlc(appliedHlc, cs.toHlc);
        }

        // Advance only forward, after applying, so an interrupted apply
        // re-pulls next time rather than skipping a seq.
        if (appliedThrough > lastApplied) {
          await _peerCursors.upsert(
            peerDeviceId: peerId,
            provider: providerId,
            baseSeqApplied: baseSeqApplied,
            lastSeqApplied: appliedThrough,
            appliedHlcHigh: appliedHlc,
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
      peerManifests: peerManifests,
      retiredPeerIds: retiredPeerIds,
      retiredPeerHasFiles: retiredPeerHasFiles,
    );
  }

  static String? _maxHlc(String? a, String? b) {
    if (a == null) return b;
    if (b == null) return a;
    return a.compareTo(b) >= 0 ? a : b;
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
