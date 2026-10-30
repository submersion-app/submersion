part of 'nearby_link_manager.dart';

/// Links other devices open: who they are and which session they get.
extension _NearbyLinkIncoming on NearbyLinkManager {
  /// [transportId] is where [deviceId] can be dialled: called only for
  /// links this device opened. A link the peer opened arrives under its
  /// central's id, which on Bluetooth is not the address it advertises.
  void _learn(String transportId, String deviceId) {
    _deviceByTransport[transportId] = deviceId;
    _transportByDevice[deviceId] = transportId;
    _strangerSince.remove(transportId);
    _strangerWait.remove(transportId);
  }

  Future<void> _onIncoming(NearbyEndpoint endpoint) async {
    // Entering demo mode closes the gate before the app restarts, with the
    // radio still on: no session may run in between.
    if (_disposed || !_foreground || DemoModeGate.instance.isActive) {
      await endpoint.close();
      return;
    }
    final NearbyIncoming incoming;
    try {
      incoming = await NearbySession(
        endpoint: endpoint,
        identity: await _identity(),
        secrets: _secrets,
        pairingNonce: _pairingNonce.isEmpty ? null : _pairingNonce,
      ).accept(allowPairing: _pairingMode, allowCard: _cardHost != null);
    } on Object catch (e) {
      NearbyLinkManager._log.info(
        'Nearby incoming from ${endpoint.transportId} refused: $e',
      );
      if (_pairingMode) _reportPairingRefusal(e);
      // A refusal naming a paired peer goes on its row, as one met by
      // dialling does: often both sides refuse at once (another library),
      // and this side may be the one that never dials (a Linux peer).
      final peer = e is NearbySessionRefused ? e.peerDeviceId : null;
      if (peer != null && await _peers.get(peer) != null) {
        await _recordRefusal(
          endpoint.transportId,
          e as NearbySessionRefused,
          dialled: false,
        );
      }
      return;
    }
    switch (incoming) {
      case NearbyIncomingSync(:final channel):
        // With the automatic switch off the radio is on only for pairing
        // or a Sync now: any other paired device that dials in is turned
        // away, as one this device dialled is.
        if (!_autoSyncEnabled() &&
            !_syncNowWaiters.containsKey(channel.peer.deviceId)) {
          await channel.close();
          return;
        }
        await _run(channel);
      case NearbyIncomingCard(:final channel):
        final host = _cardHost;
        if (host == null) {
          await channel.close();
        } else {
          host.onIncoming(channel);
        }
      case NearbyIncomingPairing(:final pairing):
        await _offer(
          NearbyPairingHandle._(
            this,
            pairing,
            transportId: endpoint.transportId,
            dialled: false,
            initiatorKey: pairing.preview.nonce,
          ),
        );
    }
  }
}
