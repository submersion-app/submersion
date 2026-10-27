import 'package:drift/drift.dart';

import 'package:submersion/core/database/database.dart';

/// Why the last session with a peer failed.
enum NearbyPeerError {
  /// This device needs a newer app to sync with the peer.
  newerApp,

  /// The peer needs a newer app.
  peerOlderApp,
  differentLibrary,

  /// The peer no longer recognises this device.
  notPaired,
  applyFailed,
  bluetoothOff,
  unreachable;

  /// True for the errors the diver has to act on, which raise the home
  /// chip; the others clear on their own.
  bool get isLasting => switch (this) {
    newerApp || peerOlderApp || differentLibrary || notPaired => true,
    applyFailed => true,
    bluetoothOff || unreachable => false,
  };
}

/// The error stored on [peer]'s row; a name this build does not know reads
/// as none.
NearbyPeerError? nearbyPeerErrorOf(NearbyPeer peer) {
  final name = peer.lastError;
  if (name == null) return null;
  for (final e in NearbyPeerError.values) {
    if (e.name == name) return e;
  }
  return null;
}

/// The paired-devices table.
class NearbyPeerStore {
  NearbyPeerStore(this._db);

  final AppDatabase _db;

  Stream<List<NearbyPeer>> watchAll() => (_db.select(
    _db.nearbyPeers,
  )..orderBy([(t) => OrderingTerm.asc(t.pairedAt)])).watch();

  Future<List<NearbyPeer>> all() => (_db.select(
    _db.nearbyPeers,
  )..orderBy([(t) => OrderingTerm.asc(t.pairedAt)])).get();

  Future<NearbyPeer?> get(String peerDeviceId) => (_db.select(
    _db.nearbyPeers,
  )..where((t) => t.peerDeviceId.equals(peerDeviceId))).getSingleOrNull();

  NearbyPeerError? errorOf(NearbyPeer peer) => nearbyPeerErrorOf(peer);

  /// A new pairing, or a re-pairing that starts this peer's progress over.
  Future<void> upsertPaired({
    required String peerDeviceId,
    required String displayName,
    required int pairedAt,
  }) => _db
      .into(_db.nearbyPeers)
      .insertOnConflictUpdate(
        NearbyPeersCompanion.insert(
          peerDeviceId: peerDeviceId,
          displayName: displayName,
          pairedAt: pairedAt,
          lastSyncedAt: const Value(null),
          lastSeenAt: const Value(null),
          peerAppliedHlcHigh: const Value(null),
          lastError: const Value(null),
          resumeBaseId: const Value(null),
          resumePartIndex: const Value(null),
          resumeOfferedAt: const Value(null),
        ),
      );

  Future<void> _update(String id, NearbyPeersCompanion values) => (_db.update(
    _db.nearbyPeers,
  )..where((t) => t.peerDeviceId.equals(id))).write(values);

  Future<void> rename(String id, String name) =>
      _update(id, NearbyPeersCompanion(displayName: Value(name)));

  Future<void> markSeen(String id, int at) =>
      _update(id, NearbyPeersCompanion(lastSeenAt: Value(at)));

  /// A clean session. A null [peerAppliedHlcHigh] keeps the last ack.
  Future<void> markSynced(
    String id, {
    required int at,
    String? peerAppliedHlcHigh,
  }) => _update(
    id,
    NearbyPeersCompanion(
      lastSyncedAt: Value(at),
      peerAppliedHlcHigh: peerAppliedHlcHigh == null
          ? const Value.absent()
          : Value(peerAppliedHlcHigh),
    ),
  );

  /// What the peer reported holding of this device's rows.
  Future<void> setPeerAck(String id, String hlc) =>
      _update(id, NearbyPeersCompanion(peerAppliedHlcHigh: Value(hlc)));

  Future<void> setError(String id, NearbyPeerError? error) =>
      _update(id, NearbyPeersCompanion(lastError: Value(error?.name)));

  /// Records (or, with no arguments, clears) the full copy being received.
  Future<void> setResume(
    String id, {
    String? baseId,
    int? partIndex,
    int? offeredAt,
  }) => _update(
    id,
    NearbyPeersCompanion(
      resumeBaseId: Value(baseId),
      resumePartIndex: Value(partIndex),
      resumeOfferedAt: Value(offeredAt),
    ),
  );

  Future<void> remove(String id) => (_db.delete(
    _db.nearbyPeers,
  )..where((t) => t.peerDeviceId.equals(id))).go();
}
