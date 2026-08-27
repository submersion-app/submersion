import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/crypto/keyslots.dart';
import 'package:submersion/core/services/sync/crypto/recovery_code.dart';
import 'package:submersion/core/services/sync/crypto/sync_encryption_service.dart'
    show WrongPassphraseException;
import 'package:submersion/features/backup/data/services/backup_encryption_key_store.dart';

/// The recovery code plus the key id minted when backup encryption is enabled.
class EnableBackupEncryptionResult {
  final String recoveryCode;
  final String libraryKeyId;

  const EnableBackupEncryptionResult({
    required this.recoveryCode,
    required this.libraryKeyId,
  });
}

/// Local-only lifecycle for password-protected backups: create the key, rewrap
/// the passphrase slot, rotate the recovery slot. Each `.sbe` embeds its own
/// keyslots, so there is no cross-device unlock and no cloud state -- this is a
/// much simpler sibling of [SyncEncryptionService].
class BackupEncryptionService {
  static final _log = LoggerService.forClass(BackupEncryptionService);

  final BackupEncryptionKeyStore _keyStore;
  final Uuid _uuid = const Uuid();

  BackupEncryptionService({required BackupEncryptionKeyStore keyStore})
    : _keyStore = keyStore;

  /// Wrap the backup master key with a fresh passphrase slot and recovery slot,
  /// persist local custody, and return the recovery code.
  ///
  /// Re-enabling after "Turn off encryption" ADOPTS the retained key rather
  /// than minting a new one. Turn-off only flips the prefs flag (it never
  /// clears the key/mirror), so backups written under the previous key share
  /// its `libraryKeyId`; reusing it keeps those backups restoring silently with
  /// the cached key on this device instead of being stranded behind a brand-new
  /// key. A fresh enable (no retained key) mints a random master key.
  Future<EnableBackupEncryptionResult> enable({
    required String passphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    final retained = await _keyStore.loadKey();
    final SecretKey mlk;
    final String libraryKeyId;
    final List<int> mlkBytes;
    if (retained != null) {
      mlk = retained.mlk;
      libraryKeyId = retained.libraryKeyId;
      mlkBytes = await mlk.extractBytes();
    } else {
      mlkBytes = _randomBytes(32);
      mlk = SecretKey(mlkBytes);
      libraryKeyId = _uuid.v4();
    }
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
    await _keyStore.saveKey(libraryKeyId: libraryKeyId, mlkBytes: mlkBytes);
    await _keyStore.saveKeyslotMirror(file.toJsonBytes());
    _log.info('Backup encryption enabled (key $libraryKeyId)');
    return EnableBackupEncryptionResult(
      recoveryCode: recoveryCode,
      libraryKeyId: libraryKeyId,
    );
  }

  /// Rewrap the passphrase slot with a new passphrase. The master key and the
  /// recovery slot are untouched (this is NOT key rotation).
  Future<void> changePassphrase({
    required String currentSecret,
    required String newPassphrase,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlocked(currentSecret);
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'passphrase',
        secret: newPassphrase,
        mlk: mlk,
        kdf: kdf,
      ),
    );
    await _keyStore.saveKeyslotMirror(updated.toJsonBytes());
    _log.info('Backup passphrase changed');
  }

  /// Replace the recovery slot with a freshly generated code and return it.
  Future<String> regenerateRecoveryCode({
    required String currentSecret,
    KdfParams kdf = const KdfParams(),
  }) async {
    final (file, mlk) = await _unlocked(currentSecret);
    final code = RecoveryCode.generate();
    final updated = file.withReplacedSlot(
      await Keyslots.createSlot(
        type: 'recovery',
        secret: code,
        mlk: mlk,
        kdf: kdf,
      ),
    );
    await _keyStore.saveKeyslotMirror(updated.toJsonBytes());
    _log.info('Backup recovery code regenerated');
    return code;
  }

  Future<(KeyslotFile, SecretKey)> _unlocked(String secret) async {
    final bytes = await _keyStore.loadKeyslotMirror();
    if (bytes == null) throw const WrongPassphraseException();
    final file = KeyslotFile.fromJsonBytes(bytes);
    final mlk = await Keyslots.tryUnwrap(file: file, secret: secret);
    if (mlk == null) throw const WrongPassphraseException();
    return (file, mlk);
  }

  static Uint8List _randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List<int>.generate(n, (_) => r.nextInt(256)));
  }
}
