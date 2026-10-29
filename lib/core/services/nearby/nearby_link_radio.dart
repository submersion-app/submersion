part of 'nearby_link_manager.dart';

/// The radio's bookkeeping: pairings that lost their other half, turning
/// the radio off, and what the paired-devices rows say about Bluetooth.
extension _NearbyLinkRadio on NearbyLinkManager {
  /// Once per run, drops each half of a pairing whose other half is gone.
  ///
  /// A secret with no paired-devices row (the app stopped between storing
  /// the secret and writing the row) cannot be seen or unpaired from
  /// Settings. A row with no secret here came in with the database (a
  /// restored backup, or a copy from another device): it can never sync,
  /// and until it ages out it would hold tombstone cleanup back.
  Future<void> _pruneOrphans() async {
    try {
      final rows = {for (final p in await _peers.all()) p.peerDeviceId};
      final secrets = await _secrets.all();
      for (final id in secrets.keys) {
        if (!rows.contains(id)) await _secrets.remove(id);
      }
      for (final id in rows) {
        if (secrets.containsKey(id)) continue;
        await _peers.remove(id);
        await _cursors.remove(id, nearbyCursorProvider);
      }
    } on Object catch (e) {
      NearbyLinkManager._log.warning('Nearby pairing cleanup failed: $e');
    }
  }

  Future<void> _stopRadio() async {
    if (!_running) return;
    _running = false;
    await _carrier.stopScanning();
    await _carrier.stopAdvertising();
    _emitState();
  }

  /// While the radio is off, every row says so, unless it already carries
  /// an error the diver has to act on.
  Future<void> _markRadioOff() async {
    for (final peer in await _peers.all()) {
      final error = _peers.errorOf(peer);
      if (error == NearbyPeerError.bluetoothOff) continue;
      if (error == null || !error.isLasting) {
        await _peers.setError(peer.peerDeviceId, NearbyPeerError.bluetoothOff);
      }
    }
  }

  Future<void> _clearRadioOff() async {
    for (final peer in await _peers.all()) {
      if (_peers.errorOf(peer) == NearbyPeerError.bluetoothOff) {
        await _peers.setError(peer.peerDeviceId, null);
      }
    }
  }
}
