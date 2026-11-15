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
  /// This device's copies go first, before any cloud call (issue #4572): a
  /// cloud request that stalls, or a background worker the OS stops while it
  /// waits on one, must not leave old backups piling up on the device. A
  /// backup kept nowhere else is then gone; one with a copy off the device
  /// stays, without its local copy, for the cloud steps below.
  ///
  /// The cloud folder is then listed so this device's pin markers can be
  /// brought in line with its pins, and a record whose cloud copy another
  /// device has pinned keeps that copy. With "count backups from all
  /// devices" on for this folder, the whole folder is then pruned to
  /// [keepCount] as well (issue #3503). Neither step can fail the prune.
  Future<void> pruneOldBackups(int keepCount) async {
    final history = getBackupHistory(); // Already sorted newest-first
    final eligible = history
        .where((r) => r.type == BackupType.manual && !r.pinned)
        .toList();
    final pruned = eligible.length <= keepCount
        ? const <BackupRecord>[]
        : eligible.sublist(keepCount);
    if (pruned.isNotEmpty) {
      // Automatic backups are manual-type records too; only pre-migration
      // and pinned records are exempt.
      _log.info('Pruning ${pruned.length} old backups');
    }
    final toDelete = await _pruneLocalCopies(pruned);

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

  /// The first step of [pruneOldBackups]: deletes the local copy of each
  /// of [pruned] without a single cloud call. A backup with no copy off the
  /// device is removed outright; one with a cloud or extra copy loses its
  /// local copy and is returned, cloud-only, for the cloud steps. So is one
  /// whose local copy could not be deleted, unchanged, to be tried again.
  Future<List<BackupRecord>> _pruneLocalCopies(
    List<BackupRecord> pruned,
  ) async {
    final remaining = <BackupRecord>[];
    for (final record in pruned) {
      final offDevice =
          record.cloudFileId != null || record.extraCloudCopies.isNotEmpty;
      try {
        if (!offDevice) {
          await _deleteBackup(record, deleteCloud: false);
          continue;
        }
        if (record.localPath == null) {
          remaining.add(record);
          continue;
        }
        await _deleteLocalCopy(record);
        // Saved per record, not once at the end: [_deleteLocalCopy] reads the
        // history to see who else uses a path, and a worker stopped mid-way
        // leaves no record pointing at a file it deleted.
        final cloudOnly = record.withoutLocalCopy();
        await _preferences.updateRecord(cloudOnly);
        remaining.add(cloudOnly);
      } catch (e, st) {
        // Best-effort, as below: a backup this platform refuses to delete
        // stays in history and is retried on every future prune.
        _log.warning(
          'Failed to prune local copy of ${record.filename}; will retry',
          error: e,
          stackTrace: st,
        );
        if (offDevice) remaining.add(record);
      }
    }
    return remaining;
  }

  /// Deletes [record]'s file on this device (a filesystem path or an SAF
  /// document URI), if it has one and no other record in the history uses
  /// it: backup filenames are only second-precise, so two backups made in
  /// the same second share one path, and the one kept must keep its file.
  Future<void> _deleteLocalCopy(BackupRecord record) async {
    final ref = record.localPath;
    if (ref == null) return;
    final shared = _preferences.getHistory().any(
      (r) => r.id != record.id && r.localPath == ref,
    );
    if (shared) {
      _log.info('Kept local file another backup still uses: $ref');
      return;
    }
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
  /// whose local copies [_pruneLocalCopies] has already deleted where it
  /// could, and their cloud copies, except a cloud copy whose stem is in
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
    if (holdCloudCopies) {
      // Their local copies are gone already ([_pruneLocalCopies]), so an
      // unreadable folder (a signed-out provider) never lets backups pile up
      // on the device; the records stay, cloud-only, for the next prune.
      toDelete = [
        for (final r in toDelete)
          if (r.cloudFileId == null || !here(r)) r,
      ];
    }

    // Cloud copies next, pushed in one batch on a backend that defers
    // deletes (Git). A record goes only after that push: if it fails, the
    // records whose cloud copy it covered stay, cloud-only, and the next
    // prune deletes them again.
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

    // Extra copies' deletes (issue #3782) are pushed once per account below.
    final extraFlushes = Set<CloudStorageProvider>.identity();
    for (final record in toDelete) {
      if (!cloudPushed && record.cloudFileId != null) continue;
      try {
        await _deleteBackup(
          record,
          deleteCloud: false,
          extraFlushes: extraFlushes,
        );
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
    await _flushExtraDeletes(extraFlushes);
    return deleted;
  }
}
