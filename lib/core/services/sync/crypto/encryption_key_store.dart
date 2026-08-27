import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';

/// The unlocked master key for the current encrypted library.
class UnlockedKey {
  final String libraryKeyId;
  final SecretKey mlk;

  const UnlockedKey({required this.libraryKeyId, required this.mlk});
}

/// Device-local custody of the master library key and a mirror of the last
/// keyslot file written to the cloud (needed for self-heal: the passphrase
/// is not retained, so the wrapped file cannot be regenerated locally).
class EncryptionKeyStore {
  static const _keyIdKey = 'sync_encryption_library_key_id';
  static const _mlkKey = 'sync_encryption_mlk';
  static const _mirrorKey = 'sync_encryption_keyslot_mirror';

  final FallbackSecureStorage _storage;

  EncryptionKeyStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  Future<void> saveKey({
    required String libraryKeyId,
    required List<int> mlkBytes,
  }) async {
    await _storage.write(key: _keyIdKey, value: libraryKeyId);
    await _storage.write(key: _mlkKey, value: base64Encode(mlkBytes));
  }

  Future<UnlockedKey?> loadKey() async {
    final keyId = await _storage.read(key: _keyIdKey);
    final mlk = await _storage.read(key: _mlkKey);
    if (keyId == null || mlk == null) return null;
    return UnlockedKey(libraryKeyId: keyId, mlk: SecretKey(base64Decode(mlk)));
  }

  Future<void> clearKey() async {
    await _storage.delete(key: _keyIdKey);
    await _storage.delete(key: _mlkKey);
  }

  Future<void> saveKeyslotMirror(Uint8List bytes) =>
      _storage.write(key: _mirrorKey, value: base64Encode(bytes));

  Future<Uint8List?> loadKeyslotMirror() async {
    final v = await _storage.read(key: _mirrorKey);
    return v == null ? null : base64Decode(v);
  }

  Future<void> clearKeyslotMirror() => _storage.delete(key: _mirrorKey);
}
