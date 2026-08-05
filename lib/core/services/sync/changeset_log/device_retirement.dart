import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/sync/changeset_log/changeset_log_layout.dart';
import 'package:submersion/core/services/sync/changeset_log/retirement_marker.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_liveness.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// Retires peers whose manifest has been idle past the retirement period:
/// writes a durable retirement marker FIRST (so the returning device always
/// detects it and rejoins through the fence), then deletes the peer's
/// manifest, base parts, and changesets. Wholly best-effort and idempotent:
/// leftover files after a partial sweep are retried whenever the reader
/// reports them ([sweep]'s retiredPeerHasFiles); markers persist until the
/// retired device itself rejoins and deletes its own.
class DeviceRetirement {
  DeviceRetirement({
    this.retirementPeriodMillis = SyncLiveness.retirementPeriodMillis,
  });

  final int retirementPeriodMillis;

  /// Returns the set of peer device ids whose retirement markers are durably
  /// present after this sweep: [alreadyRetired] (markers observed in the
  /// listing) plus every candidate whose marker upload succeeded just now.
  /// Tombstone GC treats EXACTLY this set as fenced -- a stale peer whose
  /// marker upload failed stays in the GC constraint set, so GC can never
  /// outrun the fence.
  Future<Set<String>> sweep({
    required CloudStorageProvider provider,
    required String folderId,
    required String selfDeviceId,
    required List<SyncManifest> peerManifests,
    required Set<String> alreadyRetired,
    required bool retiredPeerHasFiles,
    required int nowMillis,
  }) async {
    final candidates = <String>[
      for (final m in peerManifests)
        if (m.deviceId != selfDeviceId &&
            !alreadyRetired.contains(m.deviceId) &&
            nowMillis - m.updatedAt > retirementPeriodMillis)
          m.deviceId,
    ];
    final durablyMarked = {...alreadyRetired};
    if (candidates.isEmpty && !retiredPeerHasFiles) return durablyMarked;

    final toDelete = {...alreadyRetired};
    for (final id in candidates) {
      // Marker BEFORE deletion: a partially retired device must still fence.
      // Per-candidate failure tolerance: one failed upload must not abort the
      // others, and a failed id is simply not reported as durably marked.
      try {
        final marker = RetirementMarker(deviceId: id, retiredAt: nowMillis);
        await provider.uploadFile(
          marker.toBytes(),
          ChangesetLogLayout.retiredMarkerName(id),
          folderId: folderId,
        );
      } catch (_) {
        continue; // retried next sync; peer keeps blocking GC until then
      }
      toDelete.add(id);
      durablyMarked.add(id);
    }

    try {
      final files = await provider.listFiles(
        folderId: folderId,
        namePattern: ChangesetLogLayout.prefix,
      );
      for (final f in files) {
        final id = ChangesetLogLayout.deviceIdOf(f.name);
        if (id == null || !toDelete.contains(id)) continue;
        if (ChangesetLogLayout.isRetiredMarker(f.name)) continue;
        try {
          await provider.deleteFile(f.id);
        } catch (_) {
          // Leftovers are retried on a later sweep (retiredPeerHasFiles).
        }
      }
    } catch (_) {
      // Listing failed; markers are durable, deletion retries later.
    }
    return durablyMarked;
  }
}
