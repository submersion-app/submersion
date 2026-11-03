part of 'backup_service.dart';

/// Why a database is refused as a backup: it lacks Submersion's tables.
const String _notSubmersionBackupMessage =
    'File does not appear to be a Submersion backup (missing expected tables)';

/// A browser's restore (issue #4121); see [BackupService.restoreFromImage].
extension _BackupServiceImageRestore on BackupService {
  /// Restores [bytes], a backup as a file holds it, plain or encrypted: a
  /// browser's restore, where the picker reads the file into memory and
  /// there is no file backup to take first.
  ///
  /// The checks a file restore makes come first (decryption, a SQLite file
  /// with Submersion's tables, a schema no newer than this build), so a
  /// refusal changes nothing. Then [safetyCopy] runs, the browser's stand-in
  /// for the backup a file restore takes, then the swap with the same sync
  /// re-baseline. [RestoreMode.replace] mints a pending replace.
  ///
  /// Throws [BackupEncryptedException] when no key here opens an encrypted
  /// backup and no [encryptionSecret] was given, so the caller can ask.
  /// [onMigrationProgress] hears an older backup's upgrade ladder.
  Future<void> _restoreFromImage(
    Uint8List bytes, {
    RestoreMode mode = RestoreMode.merge,
    String? encryptionSecret,
    Future<void> Function()? safetyCopy,
    void Function(int currentStep, int totalSteps)? onMigrationProgress,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.restore);
    _log.info('Starting restore from a backup in memory (mode: $mode)');
    final plain = await _plaintextImage(bytes, encryptionSecret);
    await _checkRestorableImage(plain);
    await safetyCopy?.call();
    await _replaceAndRebaselineSync(
      () => _restoreImage(plain, onMigrationProgress: onMigrationProgress),
    );
    await _armPostRestoreSync(mode);
    _log.info('Restore from a backup in memory completed');
  }

  /// [bytes] decrypted when encrypted, in the order a file restore tries
  /// the keys: this device's sync key, its backup key, then [secret].
  Future<Uint8List> _plaintextImage(Uint8List bytes, String? secret) async {
    if (!BackupCryptoImage.isEncrypted(bytes)) return bytes;
    final keyId = BackupCryptoImage.libraryKeyIdOf(bytes);
    for (final key in [
      await _encryptionKeyStore?.loadKey(),
      await _backupEncryptionKeyStore?.loadKey(),
    ]) {
      if (key != null && key.libraryKeyId == keyId) {
        return BackupCryptoImage.decryptWithKey(
          bytes,
          mlk: key.mlk,
          expectedLibraryKeyId: key.libraryKeyId,
        );
      }
    }
    if (secret != null) {
      return BackupCryptoImage.decrypt(bytes, secret: secret);
    }
    throw const BackupEncryptedException();
  }

  Future<void> _checkRestorableImage(Uint8List image) async {
    // Neither SQLite nor an encrypted backup: most likely a copy of a
    // password-protected database, as the file restore says.
    if (!isSqliteImage(image)) {
      throw const BackupException(BackupService.unreadableCopyNoKeyMessage);
    }
    final BackupImageInfo info;
    try {
      info = await inspectBackupImage(image);
    } catch (e) {
      throw BackupException('File is not a valid database: $e');
    }
    if (!info.hasSubmersionTables) {
      throw const BackupException(_notSubmersionBackupMessage);
    }
    if (info.schemaVersion > AppDatabase.currentSchemaVersion) {
      throw BackupNewerSchemaException(
        backupSchemaVersion: info.schemaVersion,
        supportedSchemaVersion: AppDatabase.currentSchemaVersion,
      );
    }
  }
}
