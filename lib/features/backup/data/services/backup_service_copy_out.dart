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
/// for it (a SAF stream, a cloud download, or a restore's decrypted copy).
class PreparedBackupFile {
  PreparedBackupFile(this.path, {required this.isTemp, String? fileName})
    : fileName = fileName ?? p.basename(path);

  final String path;

  /// The name the file goes out under: what the receiving device sees, and
  /// the name a saved copy takes in the chosen folder. It differs from
  /// [path]'s name for a save's temp copy.
  final String fileName;

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
      return _fetchCopy(
        record,
        purpose,
        (dest) => _safPort.readBackup(documentUri: localRef, destPath: dest),
      );
    }
    if (localRef != null && await File(localRef).exists()) {
      return PreparedBackupFile(
        localRef,
        isTemp: false,
        fileName: await _outgoingName(localRef, record.filename),
      );
    }
    if (await _cloudCopyHere(record)) {
      return _fetchCopy(
        record,
        purpose,
        (dest) => _cloudProvider!.downloadToFile(record.cloudFileId!, dest),
      );
    }
    if (record.cloudFileId != null && record.cloudAccountId != null) {
      throw BackupCopyInOtherAccountException(record.cloudAccountId!);
    }
    throw const BackupException('Backup file not found locally or in cloud');
  }

  /// Fetches [record] with [write] into a unique staging file, so a failed
  /// fetch deletes only its own partial file. A share copy is then moved to
  /// the backup's own name, replacing an earlier share copy only once the
  /// new one is complete: a receiving app may still be reading that one.
  Future<PreparedBackupFile> _fetchCopy(
    BackupRecord record,
    BackupCopyPurpose purpose,
    Future<void> Function(String dest) write,
  ) async {
    final tempDir = await resolveSyncTempDir();
    final staging = p.join(tempDir.path, _restoreCopyName(record.filename));
    try {
      await write(staging);
    } catch (_) {
      await PreparedBackupFile(staging, isTemp: true).discard();
      rethrow;
    }
    final name = await _outgoingName(staging, record.filename);
    if (purpose == BackupCopyPurpose.save) {
      return PreparedBackupFile(staging, isTemp: true, fileName: name);
    }
    final shared = await File(staging).rename(p.join(tempDir.path, name));
    return PreparedBackupFile(shared.path, isTemp: true);
  }

  /// [filename], with an `.sbe` extension when the bytes at [path] are an
  /// encrypted envelope. With sync encryption on, a local `X.db` is uploaded
  /// as `X.sbe` while its record keeps the `.db` name, and a file named
  /// `.db` that is not SQLite would mislead any other tool.
  Future<String> _outgoingName(String path, String filename) async {
    if (p.extension(filename) == BackupCrypto.fileExtension ||
        !await BackupCrypto.isEncryptedBackup(path)) {
      return filename;
    }
    return p.basenameWithoutExtension(filename) + BackupCrypto.fileExtension;
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
