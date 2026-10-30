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

  /// Index updates are read, change, write: run one at a time so two
  /// pairings stored together both stay listed.
  Future<void> _tail = Future.value();

  Future<T> _serial<T>(Future<T> Function() body) {
    final next = _tail.then((_) => body());
    _tail = next.then((_) {}, onError: (Object _) {});
    return next;
  }

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

  Future<List<String>> _index() => _readIndex(_indexKey);

  Future<void> _writeIndex(Iterable<String> ids) =>
      _storage.write(key: _indexKey, value: jsonEncode(ids.toList()));

  @override
  Future<void> store(String peerDeviceId, Uint8List secret) =>
      _serial(() async {
        await _storage.write(
          key: _key(peerDeviceId),
          value: base64Encode(secret),
        );
        await _writeIndex({...await _index(), peerDeviceId});
        await _clearRevoked(peerDeviceId);
      });

  @override
  Future<void> remove(String peerDeviceId) =>
      _serial(() => _remove(peerDeviceId));

  Future<void> _remove(String peerDeviceId) async {
    await _storage.delete(key: _key(peerDeviceId));
    await _writeIndex((await _index()).where((id) => id != peerDeviceId));
  }

  static String _revokedKey(String peerDeviceId) =>
      'nearby_revoked_$peerDeviceId';

  static const _revokedIndexKey = 'nearby_revoked_index';

  Future<List<String>> _readIndex(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null) return const [];
    try {
      return [for (final id in jsonDecode(raw) as List) id as String];
    } on Object {
      return const [];
    }
  }

  @override
  Future<void> revoke(String peerDeviceId) =>
      _serial(() => _revoke(peerDeviceId));

  Future<void> _revoke(String peerDeviceId) async {
    final secret = await secretFor(peerDeviceId);
    await _remove(peerDeviceId);
    if (secret == null) return;
    await _storage.write(
      key: _revokedKey(peerDeviceId),
      value: base64Encode(secret),
    );
    await _storage.write(
      key: _revokedIndexKey,
      value: jsonEncode(
        {...await _readIndex(_revokedIndexKey), peerDeviceId}.toList(),
      ),
    );
  }

  @override
  Future<Map<String, Uint8List>> revoked() async {
    final out = <String, Uint8List>{};
    for (final id in await _readIndex(_revokedIndexKey)) {
      final raw = await _storage.read(key: _revokedKey(id));
      if (raw == null) continue;
      try {
        out[id] = base64Decode(raw);
      } on FormatException {
        // Not one this code wrote.
      }
    }
    return out;
  }

  Future<void> _clearRevoked(String peerDeviceId) async {
    await _storage.delete(key: _revokedKey(peerDeviceId));
    await _storage.write(
      key: _revokedIndexKey,
      value: jsonEncode(
        (await _readIndex(
          _revokedIndexKey,
        )).where((id) => id != peerDeviceId).toList(),
      ),
    );
  }

  @override
  Future<Map<String, Uint8List>> all() async => {
    for (final id in await _index()) id: ?await secretFor(id),
  };
}
