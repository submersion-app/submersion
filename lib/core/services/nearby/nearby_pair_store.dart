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

  /// The keychain cannot list keys portably, so the stored peer ids are
  /// kept beside the secrets.
  static const _indexKey = 'nearby_pair_index';

  Future<List<String>> _index() async {
    final raw = await _storage.read(key: _indexKey);
    if (raw == null) return const [];
    try {
      return [for (final id in jsonDecode(raw) as List) id as String];
    } on Object {
      return const [];
    }
  }

  Future<void> _writeIndex(Iterable<String> ids) =>
      _storage.write(key: _indexKey, value: jsonEncode(ids.toList()));

  @override
  Future<void> store(String peerDeviceId, Uint8List secret) async {
    await _storage.write(key: _key(peerDeviceId), value: base64Encode(secret));
    await _writeIndex({...await _index(), peerDeviceId});
  }

  @override
  Future<void> remove(String peerDeviceId) async {
    await _storage.delete(key: _key(peerDeviceId));
    await _writeIndex((await _index()).where((id) => id != peerDeviceId));
  }

  @override
  Future<Map<String, Uint8List>> all() async => {
    for (final id in await _index()) id: ?await secretFor(id),
  };
}
