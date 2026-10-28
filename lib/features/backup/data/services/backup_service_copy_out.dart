part of 'backup_service.dart';

/// What a copy of an existing backup is made for, which decides its temp
/// name.
enum BackupCopyPurpose {
  /// Handed to the share sheet. The temp copy keeps the backup's own name,
  /// so the receiving device sees which backup it is, and it is left for
  /// RestoreTempSweep: some receiving apps read the file only when the diver
  /// finally presses Send.
  share,

  /// Copied into a folder the diver picks, then deleted at once. Its temp
  /// name carries the restore-copy prefix so it can never overwrite a share
  /// copy of the same backup that is still waiting to be read.
  save,
}

/// A backup resolved to a real file: the backup itself, or a temp copy made
/// for it (a SAF stream or a cloud download).
class PreparedBackupFile {
  const PreparedBackupFile(this.path, {required this.isTemp});

  final String path;

  /// True when [path] is a copy made for this action, which [discard]
  /// removes. A backup used in place is never deleted.
  final bool isTemp;

  Future<void> discard() async {
    if (!isTemp) return;
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best-effort temp cleanup
    }
  }
}

/// Getting an existing backup out of the app (issue #3650), kept apart from
/// the rest of [BackupService]. Nothing here adds to or changes the history.
extension _CopyOut on BackupService {
  /// Resolves [record] in the order [BackupService.restoreFromBackup] does,
  /// and returns the file's bytes untouched: an encrypted backup stays
  /// encrypted and nothing asks for a password.
  Future<PreparedBackupFile> _prepareBackupCopy(
    BackupRecord record, {
    required BackupCopyPurpose purpose,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.backup);
    final localRef = record.localPath;
    if (localRef != null && isSafRef(localRef)) {
      if (!await _safPort.exists(localRef)) {
        throw const BackupException(
          'Backup file not found locally or in cloud',
        );
      }
      final dest = await _copyOutTempPath(record, purpose);
      await _streamOrCleanUp(
        dest,
        () => _safPort.readBackup(documentUri: localRef, destPath: dest),
      );
      return PreparedBackupFile(dest, isTemp: true);
    }
    if (localRef != null && await File(localRef).exists()) {
      return PreparedBackupFile(localRef, isTemp: false);
    }
    if (await _cloudCopyHere(record)) {
      final dest = await _copyOutTempPath(record, purpose);
      await _streamOrCleanUp(
        dest,
        () => _cloudProvider!.downloadToFile(record.cloudFileId!, dest),
      );
      return PreparedBackupFile(dest, isTemp: true);
    }
    if (record.cloudFileId != null && record.cloudAccountId != null) {
      throw BackupCopyInOtherAccountException(record.cloudAccountId!);
    }
    throw const BackupException('Backup file not found locally or in cloud');
  }

  Future<String> _copyOutTempPath(
    BackupRecord record,
    BackupCopyPurpose purpose,
  ) async {
    final tempDir = await resolveSyncTempDir();
    final name = switch (purpose) {
      BackupCopyPurpose.share => record.filename,
      BackupCopyPurpose.save => _restoreCopyName(record.filename),
    };
    return p.join(tempDir.path, name);
  }

  /// Runs [write] into [dest], deleting whatever part of it landed when the
  /// write fails, so a cut-off stream leaves no partial backup behind.
  Future<void> _streamOrCleanUp(
    String dest,
    Future<void> Function() write,
  ) async {
    try {
      await write();
    } catch (_) {
      await PreparedBackupFile(dest, isTemp: true).discard();
      rethrow;
    }
  }

  /// Whether [record] is a raw copy of a protected live database, which
  /// restores only on this install: the key that opens it lives in a sidecar
  /// next to the live database and is never copied with it.
  Future<bool> _isDeviceLockedSafetyCopy(BackupRecord record) async {
    if (record.type != BackupType.preMigration &&
        record.type != BackupType.preDowngrade) {
      return false;
    }
    final path = record.localPath;
    if (path == null || isSafRef(path) || !await File(path).exists()) {
      return false;
    }
    // "Encrypt existing backups" can wrap a safety copy, and what is inside
    // cannot be read without the backup password. The current protection
    // setting is the best guess left.
    if (await BackupCrypto.isEncryptedBackup(path)) {
      return _dbAdapter.databaseKeyHex != null;
    }
    // The header, not the current setting: protection may have been turned
    // on or off since the copy was taken. A non-SQLite header is protected
    // or corrupt, and neither restores anywhere else.
    return isEncryptedDatabaseFile(path);
  }
}
