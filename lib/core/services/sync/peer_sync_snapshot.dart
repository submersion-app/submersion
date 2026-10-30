import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:submersion/core/services/sync/changeset_log/sync_manifest.dart';

/// One live peer's most recent publish, as its manifest reported it.
class PeerPublish {
  const PeerPublish({required this.deviceId, required this.publishedAt});

  final String deviceId;

  /// When the peer last published: its own clock (manifest `updatedAt`),
  /// capped by the cloud's listing time of that manifest.
  final DateTime publishedAt;
}

/// What this device knew about its sync peers at the end of its last pull.
///
/// Peer manifests are downloaded on every pull and then discarded; the
/// storage cleanup needs two facts from them long after the pull is over:
/// whether this device applied everything its peers had published (so a row
/// a peer still holds cannot be missing here), and when each peer last
/// published (so an object uploaded before that publish is one the peer has
/// already told us about). See the storage GC design, safety rules.
class PeerSyncSnapshot {
  const PeerSyncSnapshot({
    required this.takenAt,
    required this.caughtUp,
    required this.peers,
    this.providerId,
    this.hasUnappliedPeers = false,
  });

  /// When the pull started, on this device's clock. The start, not the end:
  /// a restore that lands while this sync is still publishing must find the
  /// snapshot older than its marker, since the pull read the old database.
  final DateTime takenAt;

  /// True when the pull applied every live peer cleanly and reached each
  /// one's published head: no failed records, no peer that failed to read,
  /// no peer held for a newer schema, and no peer the reader stopped short
  /// of (a gap, a corrupt changeset, an incomplete base).
  final bool caughtUp;

  /// Every other device with a manifest that is not retired, stale-epoch
  /// peers included: a peer halted awaiting adoption still uploads media.
  /// Its entry alone never allows an early delete; see [hasUnappliedPeers].
  final List<PeerPublish> peers;

  /// The sync backend the pull ran against. A snapshot from another backend
  /// says nothing about this one.
  final String? providerId;

  /// True when some device's rows may be missing here whatever its publish
  /// time says: one with files in the sync folder but no manifest yet (a
  /// first publish still uploading), or a stale-epoch peer this pull skipped
  /// (its changesets are never applied here). Early delete waits for both;
  /// the grace window still applies.
  final bool hasUnappliedPeers;

  Map<String, Object?> toJson() => {
    'takenAt': takenAt.millisecondsSinceEpoch,
    'caughtUp': caughtUp,
    'providerId': providerId,
    'hasUnappliedPeers': hasUnappliedPeers,
    'peers': [
      for (final p in peers)
        {'id': p.deviceId, 'at': p.publishedAt.millisecondsSinceEpoch},
    ],
  };

  factory PeerSyncSnapshot.fromJson(Map<String, Object?> json) {
    final peers = json['peers']! as List<Object?>;
    return PeerSyncSnapshot(
      takenAt: DateTime.fromMillisecondsSinceEpoch(json['takenAt']! as int),
      caughtUp: json['caughtUp']! as bool,
      providerId: json['providerId'] as String?,
      hasUnappliedPeers: json['hasUnappliedPeers'] as bool? ?? false,
      peers: [
        for (final raw in peers.cast<Map<String, Object?>>())
          PeerPublish(
            deviceId: raw['id']! as String,
            publishedAt: DateTime.fromMillisecondsSinceEpoch(raw['at']! as int),
          ),
      ],
    );
  }
}

/// Builds the snapshot for one finished pull that started at [now].
///
/// Fenced (retired) peers are left out: they publish nothing more. A
/// stale-epoch peer stays in [PeerSyncSnapshot.peers] (it may still be
/// uploading media for rows it will replay on adoption) but does not spoil
/// [PeerSyncSnapshot.caughtUp], since its changes are never applied here;
/// that it was skipped sets [PeerSyncSnapshot.hasUnappliedPeers] instead, so
/// its objects wait out the grace window. A peer that failed to read, is
/// held for a newer schema, or was not read to its head spoils caughtUp.
PeerSyncSnapshot buildPeerSyncSnapshot({
  required DateTime now,
  required String providerId,
  required String selfDeviceId,
  required List<SyncManifest> peerManifests,
  required Set<String> fencedPeerIds,
  required Set<String> readFailedPeerIds,
  required Set<String> newerSchemaPeerIds,
  required Set<String> incompletePeerIds,
  required Set<String> unpublishedPeerIds,
  required Set<String> skippedPeerIds,
  required int recordsFailed,
  Map<String, DateTime> manifestListedAt = const {},
}) {
  return PeerSyncSnapshot(
    takenAt: now,
    providerId: providerId,
    caughtUp:
        recordsFailed == 0 &&
        readFailedPeerIds.isEmpty &&
        newerSchemaPeerIds.isEmpty &&
        incompletePeerIds.isEmpty,
    hasUnappliedPeers:
        unpublishedPeerIds.isNotEmpty || skippedPeerIds.isNotEmpty,
    peers: [
      for (final m in peerManifests)
        if (m.deviceId != selfDeviceId && !fencedPeerIds.contains(m.deviceId))
          PeerPublish(
            deviceId: m.deviceId,
            publishedAt: _earlier(
              DateTime.fromMillisecondsSinceEpoch(m.updatedAt),
              manifestListedAt[m.deviceId],
            ),
          ),
    ],
  );
}

/// A peer's clock can run ahead, claiming a publish after an upload it never
/// saw; the cloud's listing time of its manifest caps that claim.
DateTime _earlier(DateTime own, DateTime? listed) =>
    listed != null && listed.isBefore(own) ? listed : own;

/// Device-local persistence for the last [PeerSyncSnapshot].
class PeerSyncSnapshotStore {
  PeerSyncSnapshotStore(this._prefs);

  static const key = 'sync_peer_snapshot_v1';

  final SharedPreferences _prefs;

  /// The last snapshot, or null when none was written or it cannot be read.
  PeerSyncSnapshot? read() {
    final raw = _prefs.getString(key);
    if (raw == null) return null;
    try {
      return PeerSyncSnapshot.fromJson(jsonDecode(raw) as Map<String, Object?>);
    } on Object {
      // A malformed value reads as "no snapshot", which the cleanup treats
      // as not caught up: the safe direction.
      return null;
    }
  }

  /// Throws when the platform reports the write did not persist: callers
  /// rely on it to hold cloud deletes back.
  Future<void> write(PeerSyncSnapshot snapshot) async {
    if (!await _prefs.setString(key, jsonEncode(snapshot.toJson()))) {
      throw StateError('Peer sync snapshot was not saved');
    }
  }

  /// Marks the last snapshot as not caught up, keeping its peers and time.
  ///
  /// Called when a sync starts, so only a sync that reaches its clean end
  /// (which writes a fresh snapshot) can leave the cleanup trusting it. A
  /// sync that halts for adoption or throws part way leaves this device not
  /// caught up, which defers every cloud delete: fail-closed.
  Future<void> markNotCaughtUp() async {
    final current = read();
    if (current == null || !current.caughtUp) return;
    await write(
      PeerSyncSnapshot(
        takenAt: current.takenAt,
        caughtUp: false,
        peers: current.peers,
        providerId: current.providerId,
        hasUnappliedPeers: current.hasUnappliedPeers,
      ),
    );
  }
}
