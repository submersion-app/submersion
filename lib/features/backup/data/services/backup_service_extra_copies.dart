part of 'backup_service.dart';

/// The extra accounts a backup is also copied to (issue #3782), beside the
/// main copy in [_CloudCopy]. Each account is handled on its own: a failure
/// in one is logged and never reaches the backup, the main copy or the other
/// accounts.
extension _ExtraCopies on BackupService {
  /// Uploads [sourcePath] as [storedName] to every extra account, in order.
  /// Never throws. An account the main copy also goes to is skipped, so one
  /// account never receives the same backup twice; it is not missed either.
  /// [missed] holds the accounts that got no copy.
  Future<({List<ExtraCloudCopy> copies, List<String> missed})> _copyToExtras(
    String sourcePath,
    String storedName,
  ) async {
    if (_extraCopies.isEmpty) {
      return (copies: const <ExtraCloudCopy>[], missed: const <String>[]);
    }
    final mainAccountId = await _copyAccountIdOrNull();
    final copies = <ExtraCloudCopy>[];
    final missed = <String>[];
    for (final destination in _extraCopies) {
      final accountId = destination.accountId;
      if (accountId == mainAccountId) continue;
      final provider = destination.provider;
      if (provider == null) {
        _log.warning('Extra backup copy skipped, account unreachable');
        missed.add(accountId);
        continue;
      }
      try {
        final fileId = await _uploadToCloud(
          sourcePath,
          storedName,
          via: provider,
        );
        if (fileId == null) {
          missed.add(accountId);
        } else {
          copies.add(ExtraCloudCopy(accountId: accountId, fileId: fileId));
        }
      } catch (e, stack) {
        _log.error(
          'Extra backup copy failed, other copies unaffected',
          error: e,
          stackTrace: stack,
        );
        missed.add(accountId);
      }
    }
    return (copies: copies, missed: missed);
  }

  /// The provider for [accountId] while it is an extra destination this
  /// device can reach; null otherwise.
  CloudStorageProvider? _extraProviderFor(String accountId) {
    for (final destination in _extraCopies) {
      if (destination.accountId == accountId) return destination.provider;
    }
    return null;
  }

  /// Whether any of [record]'s extra copies can be reached from here.
  bool _extraCopyReachable(BackupRecord record) => record.extraCloudCopies.any(
    (copy) => _extraProviderFor(copy.accountId) != null,
  );

  /// Deletes [record]'s extra copies from every account still reachable,
  /// pushing each account's deletes once on a backend that defers them.
  /// Never throws. A copy that cannot be reached, or whose account refuses
  /// the delete, is left where it is and forgotten with its record: keeping
  /// the record would keep a local file the diver asked to remove.
  Future<void> _deleteExtraCopies(BackupRecord record) async {
    final touched = Set<CloudStorageProvider>.identity();
    for (final copy in record.extraCloudCopies) {
      final provider = _extraProviderFor(copy.accountId);
      if (provider == null) {
        _log.warning(
          'Extra backup copy left in an account this device cannot reach: '
          '${record.filename}',
        );
        continue;
      }
      try {
        await provider.deleteFile(copy.fileId);
        touched.add(provider);
      } catch (e, stack) {
        _log.warning(
          'Failed to delete an extra backup copy of ${record.filename}',
          error: e,
          stackTrace: stack,
        );
      }
    }
    for (final provider in touched) {
      try {
        await flushDeferredWrites(provider);
      } catch (e, stack) {
        _log.warning(
          'Extra backup copy deletes not pushed',
          error: e,
          stackTrace: stack,
        );
      }
    }
  }

  /// [record] downloaded from the first extra copy that can be fetched, in
  /// the order the copies were made; null when none can.
  Future<PreparedBackupFile?> _fetchFromExtra(BackupRecord record) async {
    for (final copy in record.extraCloudCopies) {
      final provider = _extraProviderFor(copy.accountId);
      if (provider == null) continue;
      try {
        final fetched = await _fetchToTemp(
          record,
          (dest) => provider.downloadToFile(copy.fileId, dest),
        );
        _log.info('Fetched the backup from an extra copy');
        return fetched;
      } catch (e, stack) {
        _log.warning(
          'Extra backup copy could not be fetched, trying the next',
          error: e,
          stackTrace: stack,
        );
      }
    }
    return null;
  }
}
