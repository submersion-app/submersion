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
  /// [record] as a real file, wherever it lives: a SAF document streamed to
  /// temp, the local file in place, or the cloud copy downloaded to temp.
  /// The one resolution order shared by restore and by Save and Share, so a
  /// backup that restores can always be copied out. A fetched copy carries
  /// the `restore-<uuid>-` prefix [RestoreTempSweep] reclaims, and a fetch
  /// that fails part way deletes its partial file.
  Future<PreparedBackupFile> _resolveBackupSource(BackupRecord record) async {
    final localRef = record.localPath;
    bool? cloudHere;
    if (localRef != null && isSafRef(localRef)) {
      try {
        if (await _safPort.exists(localRef)) {
          return await _fetchToTemp(
            record,
            (dest) =>
                _safPort.readBackup(documentUri: localRef, destPath: dest),
          );
        }
      } catch (e, stack) {
        // The check or the read failed (a revoked folder grant, or the
        // document went between the two); the staging file is already
        // cleaned up. With no cloud copy to fall back to, this error, not
        // "not found", is the true cause.
        cloudHere = await _cloudCopyHere(record);
        if (!cloudHere) rethrow;
        _log.warning(
          'Reading the backup document failed, trying the cloud copy',
          error: e,
          stackTrace: stack,
        );
      }
      // Gone or unreadable: the cloud copy below is the same backup, as it
      // is for a missing plain local file.
    } else if (localRef != null && await File(localRef).exists()) {
      return PreparedBackupFile(localRef, isTemp: false);
    }
    if (cloudHere ?? await _cloudCopyHere(record)) {
      final provider = _cloudProvider;
      if (provider == null) {
        throw const BackupException('No cloud provider available for download');
      }
      _log.info('Downloading backup from cloud');
      return _fetchToTemp(
        record,
        (dest) => provider.downloadToFile(record.cloudFileId!, dest),
      );
    }
    if (record.cloudFileId != null && record.cloudAccountId != null) {
      throw BackupCopyInOtherAccountException(record.cloudAccountId!);
    }
    throw const BackupException('Backup file not found locally or in cloud');
  }

  Future<PreparedBackupFile> _fetchToTemp(
    BackupRecord record,
    Future<void> Function(String dest) write,
  ) async {
    final tempDir = await resolveSyncTempDir();
    final staging = PreparedBackupFile(
      p.join(tempDir.path, _restoreCopyName(record.filename)),
      isTemp: true,
    );
    try {
      await write(staging.path);
    } catch (_) {
      await staging.discard();
      rethrow;
    }
    return staging;
  }

  /// [record] as a file to save or share, its bytes untouched: an encrypted
  /// backup stays encrypted and nothing asks for a password. A share copy is
  /// moved to the backup's own name, replacing an earlier share copy only
  /// once the new one is complete: a receiving app may still be reading it.
  Future<PreparedBackupFile> _prepareBackupCopy(
    BackupRecord record, {
    required BackupCopyPurpose purpose,
  }) async {
    DemoModeGate.instance.ensureNotDemo(DemoSealedFeature.backup);
    final source = await _resolveBackupSource(record);
    final name = await _outgoingName(source.path, record.filename);
    if (!source.isTemp || purpose == BackupCopyPurpose.save) {
      return PreparedBackupFile(
        source.path,
        isTemp: source.isTemp,
        fileName: name,
      );
    }
    try {
      // The staging file is already in the temp folder; the move stays there.
      final shared = await File(
        source.path,
      ).rename(p.join(p.dirname(source.path), name));
      return PreparedBackupFile(shared.path, isTemp: true);
    } catch (_) {
      await source.discard();
      rethrow;
    }
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
