import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart'
    show UnlockedKey;

/// Device-local custody of the database security master key, cached after
/// first unlock so biometric unlock and headless background opens work.
///
/// Independent of the sync and backup key stores — distinct storage keys.
/// No keyslot mirror: the sidecar file next to the database is the durable
/// wrapped copy (see DatabaseSecuritySidecar).
class DatabaseSecurityKeyStore {
  static const String keyIdStorageKey = 'db_security_key_id';
  static const String mlkStorageKey = 'db_security_mlk';

  final FallbackSecureStorage _storage;

  DatabaseSecurityKeyStore({FlutterSecureStorage? storage})
    : _storage = FallbackSecureStorage(storage ?? const FlutterSecureStorage());

  Future<void> saveKey({
    required String libraryKeyId,
    required List<int> mlkBytes,
  }) async {
    await _storage.write(key: keyIdStorageKey, value: libraryKeyId);
    await _storage.write(key: mlkStorageKey, value: base64Encode(mlkBytes));
  }

  Future<UnlockedKey?> loadKey() async {
    final keyId = await _storage.read(key: keyIdStorageKey);
    final mlk = await _storage.read(key: mlkStorageKey);
    if (keyId == null || mlk == null) return null;
    return UnlockedKey(libraryKeyId: keyId, mlk: SecretKey(base64Decode(mlk)));
  }

  Future<void> clearKey() async {
    await _storage.delete(key: keyIdStorageKey);
    await _storage.delete(key: mlkStorageKey);
  }
}
