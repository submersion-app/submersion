part of 'nearby_link_manager.dart';

/// A pairing waiting for the diver to compare the codes on both screens.
abstract class NearbyPairingOffer {
  /// The other device's name; nothing else about it is known yet.
  String get peerName;

  /// Tells pairing attempts apart without naming the device (random, per
  /// pairing mode).
  String get peerKey;
  String get code;
  bool get bothPopulated;

  /// This diver already tapped "Same code" (perhaps before leaving the
  /// pairing page) and the other has not answered yet.
  bool get confirming;

  /// Completes once both divers confirmed: the devices are paired and the
  /// first sync has started. Throws [NearbyPairingRejected] when the other
  /// diver tapped "Not mine", or a timeout when they never answered.
  Future<void> confirm();

  Future<void> reject();
}

class NearbyPairingHandle implements NearbyPairingOffer {
  NearbyPairingHandle._(
    this._manager,
    this._pairing, {
    required this.transportId,
    required this.dialled,
    required this.initiatorKey,
  });

  final NearbyLinkManager _manager;
  final NearbyPairing _pairing;
  final String transportId;

  /// This device opened the link, so [transportId] is the peer's address.
  final bool dialled;

  /// The pairing nonce of the device that connected; with two pairings
  /// between the same two devices, the one started by the lower nonce stays.
  final String initiatorKey;

  /// This diver tapped "Same code" and the other has not answered yet.
  bool _confirming = false;

  /// The one confirm a pairing runs, however often "Same code" is tapped:
  /// a second would send a second confirm on the same link.
  Future<void>? _confirmation;

  @override
  String get peerName => _pairing.preview.name;

  @override
  String get peerKey => _pairing.preview.nonce;

  @override
  String get code => _pairing.code;

  @override
  bool get bothPopulated => _pairing.bothPopulated;

  @override
  bool get confirming => _confirming;

  @override
  Future<void> confirm() => _confirmation ??= _manager._confirm(this);

  @override
  Future<void> reject() => _manager._reject(this);
}

/// Pairing mode: offers found by dialling or by being dialled, the one kept
/// when both devices found each other, and what confirming stores.
extension _NearbyLinkPairing on NearbyLinkManager {
  Future<void> _openPairing(String transportId) async {
    _connecting.add(transportId);
    var offered = false;
    try {
      final endpoint = await _connect(transportId);
      if (endpoint == null) return;
      try {
        final pairing = await NearbySession(
          endpoint: endpoint,
          identity: await _identity(),
          secrets: _secrets,
          pairingNonce: _pairingNonce,
        ).openPairing();
        offered = true;
        await _offer(
          NearbyPairingHandle._(
            this,
            pairing,
            transportId: transportId,
            dialled: true,
            initiatorKey: _pairingNonce,
          ),
        );
      } on Object catch (e) {
        NearbyLinkManager._log.info(
          'Nearby pairing with $transportId did not open: $e',
        );
        _reportPairingRefusal(e);
        await endpoint.close();
      }
    } finally {
      _connecting.remove(transportId);
      // Tried again on a later sighting, paced by retryAfter: the other
      // device may not have opened its pairing page yet, and a scan-only
      // device it cannot dial back has no other way to meet it.
      if (!offered) _pairingTried.remove(transportId);
    }
  }

  /// Shows [handle], unless a pairing with the same device is already
  /// shown: then the one the lower pairing nonce started stays, on both.
  Future<void> _offer(NearbyPairingHandle handle) async {
    if (!_pairingMode || _disposed) {
      await handle._pairing.reject();
      return;
    }
    final peerKey = handle.peerKey;
    final existing = _pending.where((h) => h.peerKey == peerKey);
    if (existing.isNotEmpty) {
      final other = existing.first;
      final preferred = _pairingNonce.compareTo(peerKey) < 0
          ? _pairingNonce
          : peerKey;
      // Decided from the nonces alone, even over one this diver already
      // confirmed: the other device cannot know that, and both must keep
      // the same pairing. A redial under the same nonce never displaces.
      if (handle.initiatorKey == preferred && other.initiatorKey != preferred) {
        _pending.remove(other);
        await other._pairing.reject();
      } else {
        await handle._pairing.reject();
        return;
      }
    }
    _pending.add(handle);
    _emitPending();
  }

  Future<void> _confirm(NearbyPairingHandle handle) async {
    final NearbyChannel channel;
    handle._confirming = true;
    try {
      channel = await handle._pairing.confirm();
    } finally {
      _pending.remove(handle);
      _emitPending();
    }
    final peer = channel.peer;
    await _peers.upsertPaired(
      peerDeviceId: peer.deviceId,
      displayName: peer.deviceName,
      pairedAt: _now().millisecondsSinceEpoch,
    );
    if (handle.dialled) _learn(handle.transportId, peer.deviceId);
    _forgetStrangers();
    unawaited(_run(channel));
    unawaited(refresh());
  }

  Future<void> _reject(NearbyPairingHandle handle) async {
    _pending.remove(handle);
    _emitPending();
    await handle._pairing.reject();
  }
}
