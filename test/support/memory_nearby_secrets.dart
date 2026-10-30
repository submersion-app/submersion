import 'dart:typed_data';

import 'package:submersion/core/services/nearby/nearby_session.dart';

/// Pair secrets in memory, for tests.
class MemoryNearbySecrets implements NearbyPairSecrets {
  MemoryNearbySecrets([Map<String, Uint8List> initial = const {}])
    : map = {...initial};

  final Map<String, Uint8List> map;
  final revokedMap = <String, Uint8List>{};

  @override
  Future<Uint8List?> secretFor(String peerDeviceId) async => map[peerDeviceId];

  @override
  Future<void> store(String peerDeviceId, Uint8List secret) async {
    map[peerDeviceId] = secret;
    revokedMap.remove(peerDeviceId);
  }

  @override
  Future<void> remove(String peerDeviceId) async => map.remove(peerDeviceId);

  @override
  Future<void> revoke(String peerDeviceId) async {
    final secret = map.remove(peerDeviceId);
    if (secret != null) revokedMap[peerDeviceId] = secret;
  }

  @override
  Future<Map<String, Uint8List>> all() async => Map.of(map);

  @override
  Future<Map<String, Uint8List>> revoked() async => Map.of(revokedMap);
}
