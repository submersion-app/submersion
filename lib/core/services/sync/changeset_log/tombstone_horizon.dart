import 'package:submersion/core/services/sync/changeset_log/sync_liveness.dart';
import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// Outcome of a fleet-acked GC computation. [upToHlc] == null with [allowed]
/// means no live peer constrains GC (single-device library): everything past
/// the safety floor may go.
class TombstoneGcDecision {
  const TombstoneGcDecision._(this.allowed, this.upToHlc);
  const TombstoneGcDecision.blocked() : this._(false, null);
  const TombstoneGcDecision.unbounded() : this._(true, null);
  const TombstoneGcDecision.upTo(String hlc) : this._(true, hlc);

  final bool allowed;
  final String? upToHlc;
}

/// What a nearby peer (issue #3731) reported holding of this device's
/// rows, and when it was last seen.
class NearbyTombstoneAck {
  const NearbyTombstoneAck({
    required this.deviceId,
    required this.ackedHlc,
    required this.lastSeenAt,
  });

  final String deviceId;
  final String? ackedHlc;
  final int lastSeenAt;
}

/// Computes how far this device may garbage-collect its own tombstones: the
/// minimum HLC every constraining peer's manifest acknowledges having applied
/// from us. A peer with no ack entry (old-format manifest, or a device that
/// has not pulled our log yet) blocks GC entirely -- the safe default.
///
/// The ONLY thing that removes a peer from the constraint set is a durably
/// present retirement marker ([retiredPeerIds]) -- retirement fences the peer,
/// so it can never republish rows whose tombstones we drop here. Manifest age
/// deliberately does NOT exempt a peer: a stale peer whose retirement-marker
/// upload failed is unfenced, and GC'ing past it would let it resurrect
/// deleted rows when it returns.
class TombstoneHorizon {
  static TombstoneGcDecision compute({
    required String selfDeviceId,
    required Iterable<SyncManifest> peerManifests,
    required Set<String> retiredPeerIds,
    Iterable<NearbyTombstoneAck> nearbyPeers = const [],
    int? nowMillis,
  }) {
    String? min;
    var anyPeer = false;
    // A nearby peer has no manifest and no retirement marker: it constrains
    // like a cloud peer until it is unpaired (its row is gone) or silent for
    // the cloud path's whole retirement period.
    final now = nowMillis ?? DateTime.now().millisecondsSinceEpoch;
    for (final n in nearbyPeers) {
      if (now - n.lastSeenAt > SyncLiveness.retirementPeriodMillis) continue;
      final acked = n.ackedHlc;
      if (acked == null) return const TombstoneGcDecision.blocked();
      anyPeer = true;
      if (min == null || acked.compareTo(min) < 0) min = acked;
    }
    for (final m in peerManifests) {
      if (m.deviceId == selfDeviceId) continue;
      if (retiredPeerIds.contains(m.deviceId)) continue;
      final acked = m.appliedPeerHlc[selfDeviceId];
      if (acked == null) return const TombstoneGcDecision.blocked();
      anyPeer = true;
      if (min == null || acked.compareTo(min) < 0) min = acked;
    }
    if (!anyPeer) return const TombstoneGcDecision.unbounded();
    return TombstoneGcDecision.upTo(min!);
  }
}
