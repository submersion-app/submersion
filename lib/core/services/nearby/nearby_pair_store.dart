import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/nearby/nearby_session.dart';
import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// Pair secrets in the platform keychain, beside the library key. They
/// never leave the device and are not in backups.
class SecureNearbyPairStore implements NearbyPairSecrets {
  SecureNearbyPairStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  final FallbackSecureStorage _storage;

  static String _key(String peerDeviceId) => 'nearby_pair_$peerDeviceId';

  @override
  Future<Uint8List?> secretFor(String peerDeviceId) async {
    final value = await _storage.read(key: _key(peerDeviceId));
    if (value == null) return null;
    try {
      return base64Decode(value);
    } on FormatException {
      // A value this code never wrote; treat the peer as unpaired.
      return null;
    }
  }

  @override
  Future<void> store(String peerDeviceId, Uint8List secret) =>
      _storage.write(key: _key(peerDeviceId), value: base64Encode(secret));

  @override
  Future<void> remove(String peerDeviceId) =>
      _storage.delete(key: _key(peerDeviceId));
}
