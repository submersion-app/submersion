import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'package:submersion/core/services/secure_storage/fallback_secure_storage.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart'
    show UnlockedKey;

/// Device-local custody of the backup master key and a mirror of its keyslot
/// file (needed for changePassphrase / regenerateRecoveryCode: the passphrase
/// is not retained, so the wrapped file cannot be regenerated locally).
///
/// Independent of the sync [EncryptionKeyStore] -- distinct storage keys so the
/// two features never collide. Backups are local-only, so there is no cloud
/// keyslot file: each `.sbe` embeds its own keyslots and is self-decrypting.
class BackupEncryptionKeyStore {
  static const String keyIdStorageKey = 'backup_encryption_library_key_id';
  static const String mlkStorageKey = 'backup_encryption_mlk';
  static const String mirrorStorageKey = 'backup_encryption_keyslot_mirror';

  final FallbackSecureStorage _storage;

  BackupEncryptionKeyStore({FlutterSecureStorage? storage})
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

  Future<void> saveKeyslotMirror(Uint8List bytes) =>
      _storage.write(key: mirrorStorageKey, value: base64Encode(bytes));

  Future<Uint8List?> loadKeyslotMirror() async {
    final v = await _storage.read(key: mirrorStorageKey);
    return v == null ? null : base64Decode(v);
  }

  Future<void> clearKeyslotMirror() => _storage.delete(key: mirrorStorageKey);
}
