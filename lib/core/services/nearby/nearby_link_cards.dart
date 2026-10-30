part of 'nearby_link_manager.dart';

/// Buddy card swaps on the nearby link (issue #3728).
extension _NearbyLinkCards on NearbyLinkManager {
  /// Dials [transportId] and opens a card session over this device's
  /// carrier.
  Future<NearbyCardChannel> _dialCard(String transportId) async {
    if (_disposed || DemoModeGate.instance.isActive) {
      throw const NearbyConnectFailed('card mode is closed');
    }
    final identity = await _identity();
    final endpoint = await _carrier.connect(transportId);
    try {
      return await NearbySession(
        endpoint: endpoint,
        identity: identity,
        secrets: _secrets,
      ).openCard();
    } on Object {
      // The session closes its link on a refusal or a timeout; anything
      // else would leave it open, and a peripheral holds only one.
      await endpoint.close();
      rethrow;
    }
  }
}
