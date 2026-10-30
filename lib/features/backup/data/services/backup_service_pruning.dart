part of 'backup_service.dart';

/// Retention pruning after a backup: this device's own history, and the
/// cross-device rule when it is on (issue #3503). Kept apart from the rest of
/// [BackupService], which is already far past the file-size guideline.
extension BackupServicePruning on BackupService {
  /// Remove old backups beyond the retention count.
  ///
  /// Only prunes manual, unpinned records. Pre-migration records have their
  /// own retention managed by PreMigrationBackupService. Pinned records are
  /// exempt from all automatic retention.
  ///
  /// Keeps the [keepCount] most recent unpinned manual backups and deletes
  /// the rest.
  ///
  /// The cloud folder is listed first so this device's pin markers can be
  /// brought in line with its pins, and a record whose cloud copy another
  /// device has pinned keeps that copy. With "count backups from all
  /// devices" on for this folder, the whole folder is then pruned to
  /// [keepCount] as well (issue #3503). Neither step can fail the prune.
  Future<void> pruneOldBackups(int keepCount) async {
    final history = getBackupHistory(); // Already sorted newest-first
    final eligible = history
        .where((r) => r.type == BackupType.manual && !r.pinned)
        .toList();
    final toDelete = eligible.length <= keepCount
        ? const <BackupRecord>[]
        : eligible.sublist(keepCount);

    // The folder is listed only when something needs it: listing a cloud
    // service is a round trip, and on iCloud it can start downloads.
    final here = await _cloudCopyCheck();
    final ownCloud = toDelete.any((r) => r.cloudFileId != null && here(r));
    final folderKey = await crossDeviceRetentionAccountKey();
    final acrossDevices = _crossDeviceRetentionActiveFor(folderKey);
    final deviceId = await thisDeviceIdOrNull();
    final markersStale = _pinMarkersStale(here, folderKey, deviceId: deviceId);
    final listing = ownCloud || acrossDevices || markersStale
        ? await _listCloudFolder()
        : null;
    if (listing != null && markersStale) {
      await reconcilePinMarkers(listing: listing, deviceId: deviceId);
    }

    final deleted = await _pruneOwnHistory(
      toDelete,
      here: here,
      pinnedElsewhere: _stemsPinnedElsewhere(listing, deviceId: deviceId),
      // Without a listing the pins of other devices are unknown, so no cloud
      // copy goes this round; its record waits for the next prune.
      holdCloudCopies: ownCloud && listing == null,
    );
    if (acrossDevices && listing != null) {
      await _pruneAcrossDevices(
        keepCount,
        listing: [
          for (final f in listing)
            if (!deleted.contains(f.id)) f,
        ],
      );
    }
  }

  /// Deletes [record]'s file on this device (a filesystem path or an SAF
  /// document URI), if it has one.
  Future<void> _deleteLocalCopy(BackupRecord record) async {
    final ref = record.localPath;
    if (ref == null) return;
    if (isSafRef(ref)) {
      await _safPort.delete(ref);
      _log.info('Deleted SAF backup: $ref');
    } else {
      final file = File(ref);
      if (await file.exists()) {
        await file.delete();
        _log.info('Deleted local file: $ref');
      }
    }
  }

  /// [pruneOldBackups] for this device's own history: deletes [toDelete],
  /// local and cloud copies both, except a cloud copy whose stem is in
  /// [pinnedElsewhere], which stays in the folder. [here] says whether a
  /// record's cloud copy is in this folder. With [holdCloudCopies],
  /// a record with a cloud copy here is left for the next prune. Returns the
  /// ids of the cloud copies deleted.
  Future<Set<String>> _pruneOwnHistory(
    List<BackupRecord> toDelete, {
    required bool Function(BackupRecord) here,
    required Set<String> pinnedElsewhere,
    required bool holdCloudCopies,
  }) async {
    if (toDelete.isEmpty) return const {};
    _log.info('Pruning ${toDelete.length} old manual backups');
    if (holdCloudCopies) {
      // The local copy still goes, so an unreadable folder (a signed-out
      // provider) never lets backups pile up on the device; the record stays,
      // cloud-only, for the next prune to finish.
      final held = [
        for (final r in toDelete)
          if (r.cloudFileId != null && here(r)) r,
      ];
      for (final r in held) {
        if (r.localPath == null) continue;
        try {
          await _deleteLocalCopy(r);
          await _preferences.updateRecord(r.withoutLocalCopy());
        } catch (e, st) {
          _log.warning(
            'Failed to prune local copy of ${r.filename}; will retry',
            error: e,
            stackTrace: st,
          );
        }
      }
      toDelete = [
        for (final r in toDelete)
          if (!held.contains(r)) r,
      ];
    }

    // Cloud copies first, pushed in one batch on a backend that defers
    // deletes (Git). A record goes only after that push: if it fails, the
    // records whose cloud copy it covered stay, local copy and all, and the
    // next prune deletes them again.
    final provider = _cloudProvider;
    var cloudPushed = true;
    final deleted = <String>{};
    if (provider != null) {
      for (final record in toDelete) {
        final id = record.cloudFileId;
        // A copy in another account is left where it is, and so is one
        // another device has pinned.
        if (id == null || !here(record)) continue;
        if (pinnedElsewhere.contains(backupStem(record.filename))) continue;
        try {
          await provider.deleteFile(id);
          deleted.add(id);
        } catch (e, st) {
          // As for a single delete: a cloud copy this backend refuses to
          // delete does not keep its record in history.
          _log.warning(
            'Failed to delete pruned cloud backup ${record.filename}',
            error: e,
            stackTrace: st,
          );
        }
      }
      if (deleted.isNotEmpty) {
        try {
          await flushDeferredWrites(provider);
        } catch (e, st) {
          cloudPushed = false;
          deleted.clear();
          _log.warning(
            'Pruned backups not deleted from the cloud; retried next prune',
            error: e,
            stackTrace: st,
          );
        }
      }
    }

    for (final record in toDelete) {
      if (!cloudPushed && record.cloudFileId != null) continue;
      try {
        await _deleteBackup(record, deleteCloud: false);
      } catch (e, st) {
        // Best-effort: pruning is a side effect of the operation that
        // triggered it (a fresh backup, or the safety snapshot restoreFromFile
        // takes before swapping the database in). A single old backup this
        // platform refuses to delete -- outside the sandbox, on a locked
        // network share, whatever the cause -- must not abort that operation.
        // Left in history, it is retried on every future prune rather than
        // silently forgotten.
        _log.warning(
          'Failed to prune old backup ${record.filename}; will retry next '
          'time',
          error: e,
          stackTrace: st,
        );
      }
    }
    return deleted;
  }
}
