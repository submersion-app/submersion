part of 'backup_service.dart';

/// Which account a backup's cloud copy is in, and the upload that puts it
/// there (issue #3482). Kept apart from the rest of [BackupService] so the
/// copy-account rules read in one place.
extension _CloudCopy on BackupService {
  /// Uploads [sourcePath] as the cloud copy [storedName]. Never throws: the
  /// backup on this device already succeeded, so a failed copy only leaves
  /// it local-only. The account is read before the upload: a switch while it
  /// runs must not be recorded as this copy's account.
  Future<({String? fileId, String? accountId})> _copyToCloud(
    String sourcePath,
    String storedName,
  ) async {
    final accountId = await _copyAccountIdOrNull();
    try {
      final fileId = await _uploadToCloud(sourcePath, storedName);
      // Only a real file id means a cloud copy exists: the upload also gives
      // up (returning null) when the backup folder is unreachable or sync
      // encryption is locked on this device (issue #3089), and history that
      // claims `both` with no id sends restore looking for a file that was
      // never written.
      if (fileId == null) {
        _log.warning('Cloud upload skipped, backup is local-only');
      } else {
        _log.info('Backup uploaded to cloud: $fileId');
      }
      return (fileId: fileId, accountId: accountId);
    } catch (e, stack) {
      _log.error(
        'Cloud upload failed, backup is local-only',
        error: e,
        stackTrace: stack,
      );
      return (fileId: null, accountId: accountId);
    }
  }

  /// Whether [record]'s cloud copy is in the account the copy goes to now,
  /// so this provider may delete, download or adopt it. Reads the account
  /// only for a record that noted one.
  Future<bool> _cloudCopyHere(BackupRecord record) async =>
      (await _cloudCopyCheck())(record);

  /// [_cloudCopyHere] for many records, reading the accounts once.
  Future<bool Function(BackupRecord)> _cloudCopyCheck() async {
    if (_cloudProvider == null) return (_) => false;
    final pinned = _pinnedCopyAccountId;
    final sync = await _syncAccountIdOrNull();
    return (record) => cloudCopyReachable(
      record,
      copyAccountId: pinned ?? sync,
      followsSync: pinned == null,
      syncAccountId: sync,
    );
  }

  Future<String?> _copyAccountIdOrNull() async =>
      _pinnedCopyAccountId ?? await _syncAccountIdOrNull();

  /// The sync account, or null when it cannot be read: a missing name only
  /// makes Settings > Data say "the cloud".
  Future<String?> _syncAccountIdOrNull() async {
    try {
      return await _syncRepository.getSyncAccountId();
    } catch (e, stack) {
      _log.warning(
        'Could not read the sync account for the backup record',
        error: e,
        stackTrace: stack,
      );
      return null;
    }
  }
}
