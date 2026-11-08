part of 'backup_service.dart';

/// The extra accounts a backup is also copied to (issue #3782), beside the
/// main copy in [_CloudCopy]. Each account is handled on its own: a failure
/// in one is logged and never reaches the backup, the main copy or the other
/// accounts.
extension _ExtraCopies on BackupService {
  /// Uploads [sourcePath] as [storedName] to every extra account, in order.
  /// Never throws. An account the main copy also goes to is skipped, so one
  /// account never receives the same backup twice; it is not missed either.
  /// With no main provider here nothing goes there, so that account is then
  /// copied to as an extra. [missed] holds the accounts that got no copy.
  Future<({List<ExtraCloudCopy> copies, List<String> missed})> _copyToExtras(
    String sourcePath,
    String storedName,
  ) async {
    if (_extraCopies.isEmpty) {
      return (copies: const <ExtraCloudCopy>[], missed: const <String>[]);
    }
    final mainAccountId = _cloudProvider == null
        ? null
        : await _copyAccountIdOrNull();
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

  /// Runs [upload] with the bytes every copy of one backup sends. With
  /// [share] (more than one account gets a copy), sync encryption on and
  /// this device unlocked, that is one framed .sbe made for all of them,
  /// which each upload then sends verbatim: the backup is encrypted once,
  /// not once per account. Otherwise, or when the framing fails, it is
  /// [path] as [name], and each upload frames (or fails closed) on its own.
  Future<void> _withSharedUploadSource(
    String path,
    String name, {
    required bool share,
    required Future<void> Function(String path, String name) upload,
  }) async {
    final framed = share ? await _frameOnce(path, name) : null;
    if (framed == null) return upload(path, name);
    try {
      await upload(framed.path, framed.name);
    } finally {
      await _deleteQuietly(framed.path);
    }
  }

  /// [path] framed with the sync key as `<name>.sbe` in temp, as
  /// [_uploadToCloud] frames a copy; null when no framing is needed or it
  /// cannot be done here.
  Future<({String path, String name})?> _frameOnce(
    String path,
    String name,
  ) async {
    if (!(_syncPreferences?.syncEncryptionEnabled ?? false)) return null;
    String? framedPath;
    try {
      if (await BackupCrypto.isEncryptedBackup(path)) return null;
      final unlocked = await _unlockedSyncKey();
      if (unlocked == null) return null;
      final framedName =
          p.basenameWithoutExtension(name) + BackupCrypto.fileExtension;
      final tempDir = await resolveSyncTempDir();
      framedPath = p.join(tempDir.path, '${_uuid.v4()}-$framedName');
      await BackupCrypto.encryptFile(
        inPath: path,
        outPath: framedPath,
        mlk: unlocked.mlk,
        libraryKeyId: unlocked.libraryKeyId,
        keyslotBytes: unlocked.keyslotBytes,
      );
      return (path: framedPath, name: framedName);
    } catch (e, stack) {
      _log.warning(
        'Could not frame the backup once for every copy',
        error: e,
        stackTrace: stack,
      );
      if (framedPath != null) await _deleteQuietly(framedPath);
      return null;
    }
  }

  Future<void> _deleteQuietly(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {
      // best-effort temp cleanup
    }
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
  ///
  /// With [deferFlushTo], the accounts deleted from are added to it and left
  /// for the caller to push with [_flushExtraDeletes], once for many records.
  Future<void> _deleteExtraCopies(
    BackupRecord record, {
    Set<CloudStorageProvider>? deferFlushTo,
  }) async {
    final touched = deferFlushTo ?? Set<CloudStorageProvider>.identity();
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
    if (deferFlushTo == null) await _flushExtraDeletes(touched);
  }

  /// Pushes the extra copies' deletes in each of [accounts], on a backend
  /// that defers them. Never throws: the copies are forgotten either way.
  Future<void> _flushExtraDeletes(Set<CloudStorageProvider> accounts) async {
    for (final provider in accounts) {
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

  /// Re-encryption's first half for the extra copies: uploads [newPath] as
  /// [newName] to each account of [record]'s extra copies, before the record
  /// is committed, so a failure here leaves it intact and resumable.
  ///
  /// [copies] is the record's new list: a copy that could not be replaced
  /// (its account unreachable, or the upload failed) keeps its old id and
  /// sets [residual], since a plaintext copy then stays in that account.
  /// [replaced] holds the old copies to delete once the record is committed.
  Future<
    ({
      List<ExtraCloudCopy> copies,
      List<ExtraCloudCopy> replaced,
      bool residual,
    })
  >
  _reuploadExtras(BackupRecord record, String newPath, String newName) async {
    final copies = <ExtraCloudCopy>[];
    final replaced = <ExtraCloudCopy>[];
    var residual = false;
    for (final copy in record.extraCloudCopies) {
      final provider = _extraProviderFor(copy.accountId);
      String? fileId;
      if (provider != null) {
        try {
          fileId = await _uploadToCloud(newPath, newName, via: provider);
        } catch (e, stack) {
          _log.error(
            'Re-encrypt: extra copy could not be replaced: ${record.filename}',
            error: e,
            stackTrace: stack,
          );
        }
      }
      if (fileId == null) {
        residual = true;
        copies.add(copy);
        continue;
      }
      copies.add(ExtraCloudCopy(accountId: copy.accountId, fileId: fileId));
      // Path-based providers reuse the id for the same name: deleting it
      // would remove the copy just uploaded.
      if (fileId != copy.fileId) replaced.add(copy);
    }
    return (copies: copies, replaced: replaced, residual: residual);
  }

  /// Re-encryption's second half: deletes the [replaced] plaintext copies
  /// of the record [recordId], noting in [touched] each account deleted from
  /// and the records it held. True when one of them may still be there. The
  /// deletes reach a backend that defers them (Git) only through
  /// [_resetExtraHistories], run once for the whole migration.
  Future<bool> _deleteReplacedExtras(
    String recordId,
    List<ExtraCloudCopy> replaced, {
    required Map<CloudStorageProvider, Set<String>> touched,
  }) async {
    var residual = false;
    for (final copy in replaced) {
      final provider = _extraProviderFor(copy.accountId)!;
      touched.putIfAbsent(provider, () => {}).add(recordId);
      try {
        await provider.deleteFile(copy.fileId);
      } catch (e, stack) {
        residual = true;
        _log.error(
          'Re-encrypt: old extra copy could not be deleted, still present',
          error: e,
          stackTrace: stack,
        );
      }
    }
    return residual;
  }

  /// Pushes the deletes in each account of [touched] and drops the replaced
  /// copies from the history of an account that keeps one. Returns the
  /// records of every account that failed: their old copies may still be
  /// readable there.
  Future<Set<String>> _resetExtraHistories(
    Map<CloudStorageProvider, Set<String>> touched,
  ) async {
    final exposed = <String>{};
    for (final MapEntry(key: provider, value: records) in touched.entries) {
      try {
        await flushDeferredWrites(provider);
        await resetHistoryNowIfSupported(provider);
      } catch (e, stack) {
        exposed.addAll(records);
        _log.error(
          'Re-encrypt: old extra copies stay in an account or its history',
          error: e,
          stackTrace: stack,
        );
      }
    }
    return exposed;
  }

  /// The providers of the extra accounts this device can reach.
  Iterable<CloudStorageProvider> get _reachableExtraProviders => [
    for (final destination in _extraCopies) ?destination.provider,
  ];
}
