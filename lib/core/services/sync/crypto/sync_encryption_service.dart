import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/cloud_storage/cloud_storage_provider.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/crypto/crypto_errors.dart';
import 'package:submersion/core/services/sync/crypto/encryption_key_store.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';
import 'package:submersion/core/services/sync/library_epoch.dart';
import 'package:submersion/core/services/sync/library_epoch_store.dart';
import 'package:submersion/core/services/sync/sync_preferences.dart';

/// No keyslot in the file authenticated against the entered secret.
class WrongPassphraseException implements Exception {
  const WrongPassphraseException();

  @override
  String toString() => 'WrongPassphraseException';
}

class EnableEncryptionResult {
  final String recoveryCode;
  final String libraryKeyId;

  const EnableEncryptionResult({
    required this.recoveryCode,
    required this.libraryKeyId,
  });
}

/// Lifecycle operations for end-to-end encrypted sync: enable, unlock a
/// second device, rotate slots, disable, and keyslot self-heal. Transport
/// only -- callers sequence the surrounding sync/replace steps (the enable
/// and disable flows ride the existing pending-replace machinery).
class SyncEncryptionService {
  static final _log = LoggerService.forClass(SyncEncryptionService);

  final EncryptionKeyStore _keyStore;
  final SyncPreferences _preferences;
  final Uuid _uuid = const Uuid();

  SyncEncryptionService({
    required EncryptionKeyStore keyStore,
    required SyncPreferences preferences,
  }) : _keyStore = keyStore,
       _preferences = preferences;

  /// Create the library key and keyslot file, persist local custody, flag
  /// encryption on, and mint the pending library replace. The caller runs
  /// the next sync, which consumes the pending replace through the
  /// now-encrypting provider (resumable if interrupted).
  Future<EnableEncryptionResult> enable({
    required CloudStorageProvider rawProvider,
    required String passphrase,
    required LibraryEpochStore epochStore,
    required String deviceId,
    String? deviceName,
    String? appVersion,
    KdfParams kdf = const KdfParams(),
  }) async {
    final mlkBytes = _randomBytes(32);
    final mlk = SecretKey(mlkBytes);
    final libraryKeyId = _uuid.v4();
    final recoveryCode = RecoveryCode.generate();
    final file = KeyslotFile(
      version: 1,
      libraryKeyId: libraryKeyId,
      slots: [
        await Keyslots.createSlot(
          type: 'passphrase',
          secret: passphrase,
          mlk: mlk,
          kdf: kdf,
        ),
        await Keyslots.createSlot(
          type: 'recovery',
          secret: recoveryCode,
          mlk: mlk,
          kdf: kdf,
        ),
      ],
    );
    final bytes = file.toJsonBytes();
    await _uploadKeyslots(rawProvider, bytes);
    await _keyStore.saveKey(libraryKeyId: libraryKeyId, mlkBytes: mlkBytes);
    await _keyStore.saveKeyslotMirror(bytes);
    await _preferences.setSyncEncryptionEnabled(true);
    await epochStore.setPendingReplace(
      LibraryEpochMarker(
        epochId: _uuid.v4(),
        replacedAt: DateTime.now().millisecondsSinceEpoch,
        deviceId: deviceId,
        deviceName: deviceName,
        appVersion: appVersion,
      ),
    );
    _log.info('Encryption enabled (key $libraryKeyId)');
    return EnableEncryptionResult(
      recoveryCode: recoveryCode,
      libraryKeyId: libraryKeyId,
    );
  }

  /// Unlock this device against the cloud keyslot file with a passphrase or
  /// recovery code. Persists key + mirror on success.
  Future<UnlockedKey> unlock({
    required CloudStorageProvider rawProvider,
    required String secret,
  }) async {
    final fileBytes = await _downloadKeyslots(rawProvider);
    if (fileBytes == null) {
      throw const SyncEncryptionRequired(
        message: 'No keyslot file found in the cloud',
      );
    }
    final keyslotFile = KeyslotFile.fromJsonBytes(fileBytes);
    final mlk = await Keyslots.tryUnwrap(file: keyslotFile, secret: secret);
    if (mlk == null) throw const WrongPassphraseException();
    await _keyStore.saveKey(
      libraryKeyId: keyslotFile.libraryKeyId,
      mlkBytes: await mlk.extractBytes(),
    );
    await _keyStore.saveKeyslotMirror(fileBytes);
    _log.info('Unlocked encrypted library ${keyslotFile.libraryKeyId}');
    return UnlockedKey(libraryKeyId: keyslotFile.libraryKeyId, mlk: mlk);
  }

  /// Flag encryption off and mint the plaintext-republish replace. The
  /// stored key is deliberately KEPT so previously made encrypted backups
  /// still restore silently; the caller deletes the cloud keyslot file
  /// after the plaintext republish succeeds.
  Future<void> disable({
    required LibraryEpochStore epochStore,
    required String deviceId,
    String? deviceName,
    String? appVersion,
  }) async {
    await _preferences.setSyncEncryptionEnabled(false);
    await epochStore.setPendingReplace(
      LibraryEpochMarker(
        epochId: _uuid.v4(),
        replacedAt: DateTime.now().millisecondsSinceEpoch,
        deviceId: deviceId,
        deviceName: deviceName,
        appVersion: appVersion,
      ),
    );
    _log.info('Encryption disabled; plaintext republish pending');
  }

  Future<void> deleteCloudKeyslots(CloudStorageProvider rawProvider) async {
    final match = await _findKeyslotFile(rawProvider);
    if (match != null) {
      await rawProvider.deleteFile(match.id);
    }
  }

  /// Rewrap the passphrase slot with a new passphrase. Recovery slot and
  /// library key are untouched (this is NOT key rotation).
  Future<void> changePassphrase({
    required CloudStorageProvider rawProvider,
    required String currentSecret,
    required String newPassphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, _) = await _unlockedKeyslots(rawProvider, currentSecret);
    final mlk = await Keyslots.tryUnwrap(file: file, secret: currentSecret);
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'passphrase',
        secret: newPassphrase,
        mlk: mlk!,
        kdf: kdf,
      ),
    );
    final bytes = updated.toJsonBytes();
    await _uploadKeyslots(rawProvider, bytes);
    await _keyStore.saveKeyslotMirror(bytes);
    _log.info('Passphrase changed (slot rewrapped)');
  }

  /// Replace the recovery slot with a freshly generated code and return it.
  Future<String> regenerateRecoveryCode({
    required CloudStorageProvider rawProvider,
    required String passphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlockedKeyslots(rawProvider, passphrase);
    final code = RecoveryCode.generate();
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'recovery',
        secret: code,
        mlk: mlk,
        kdf: kdf,
      ),
    );
    final bytes = updated.toJsonBytes();
    await _uploadKeyslots(rawProvider, bytes);
    await _keyStore.saveKeyslotMirror(bytes);
    _log.info('Recovery code regenerated');
    return code;
  }

  /// Re-upload the mirrored keyslot file when the cloud copy is missing
  /// (same self-heal pattern as the epoch marker). No-op unless encryption
  /// is enabled and a mirror exists.
  Future<void> selfHealKeyslots(CloudStorageProvider rawProvider) async {
    if (!_preferences.syncEncryptionEnabled) return;
    final mirror = await _keyStore.loadKeyslotMirror();
    if (mirror == null) return;
    if (await _findKeyslotFile(rawProvider) != null) return;
    _log.warning('Cloud keyslot file missing; re-uploading the mirror');
    await _uploadKeyslots(rawProvider, mirror);
  }

  Future<(KeyslotFile, SecretKey)> _unlockedKeyslots(
    CloudStorageProvider rawProvider,
    String secret,
  ) async {
    var bytes = await _downloadKeyslots(rawProvider);
    bytes ??= await _keyStore.loadKeyslotMirror();
    if (bytes == null) {
      throw const SyncEncryptionRequired(
        message: 'No keyslot file found in the cloud',
      );
    }
    final file = KeyslotFile.fromJsonBytes(bytes);
    final mlk = await Keyslots.tryUnwrap(file: file, secret: secret);
    if (mlk == null) throw const WrongPassphraseException();
    return (file, mlk);
  }

  Future<CloudFileInfo?> _findKeyslotFile(CloudStorageProvider provider) async {
    final files = await provider.listFiles(
      namePattern: KeyslotFile.cloudFileName,
    );
    for (final f in files) {
      if (f.name == KeyslotFile.cloudFileName) return f;
    }
    return null;
  }

  Future<Uint8List?> _downloadKeyslots(CloudStorageProvider provider) async {
    final match = await _findKeyslotFile(provider);
    if (match == null) return null;
    return provider.downloadFile(match.id);
  }

  Future<void> _uploadKeyslots(
    CloudStorageProvider provider,
    Uint8List bytes,
  ) async {
    String? folderId;
    try {
      folderId = await provider.getOrCreateSyncFolder();
    } catch (_) {
      folderId = null;
    }
    await provider.uploadFile(
      bytes,
      KeyslotFile.cloudFileName,
      folderId: folderId,
    );
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
