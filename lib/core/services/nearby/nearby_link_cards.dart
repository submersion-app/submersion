part of 'nearby_link_manager.dart';

/// Buddy card swaps on the nearby link (issue #3728).
extension _NearbyLinkCards on NearbyLinkManager {
  /// Dials [transportId] and opens a card session over this device's
  /// carrier.
  Future<NearbyCardChannel> _dialCard(String transportId) async {
    if (_disposed || DemoModeGate.instance.isActive) {
      throw const NearbyConnectFailed('card mode is closed');
    }
    final endpoint = await _carrier.connect(transportId);
    return NearbySession(
      endpoint: endpoint,
      identity: await _identity(),
      secrets: _secrets,
    ).openCard();
  }
}
