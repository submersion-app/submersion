part of 'backup_service.dart';

/// Cross-device retention (issue #3503): pin markers in the shared cloud
/// folder, and the rule that prunes that folder across devices. Kept apart
/// from the rest of [BackupService] so the rules read in one place.
extension BackupServiceRetention on BackupService {
  /// This device's id, or null when it cannot be read or is empty. An empty
  /// id would hash to the same tag on every such device, so it is no id.
  Future<String?> thisDeviceIdOrNull() async {
    try {
      final id = await _syncRepository.getDeviceId();
      return id.isEmpty ? null : id;
    } catch (e) {
      _log.warning('Device id unavailable for pin markers: $e');
      return null;
    }
  }

  /// Makes this device's markers in the cloud folder match its pins: a
  /// marker for every pinned record whose cloud copy is in [listing] (the
  /// folder is listed when it is not given), and none for a backup this
  /// device no longer pins. Other devices' markers are never touched.
  ///
  /// Best-effort: it covers pins made before markers existed and marker
  /// writes that failed (offline), and is retried on every prune.
  Future<void> reconcilePinMarkers({List<CloudFileInfo>? listing}) async {
    final provider = _cloudProvider;
    if (provider == null) return;
    final deviceId = await thisDeviceIdOrNull();
    if (deviceId == null) return;
    final files = listing ?? await _listCloudFolder();
    if (files == null) return;
    final folderId = await _getOrCreateCloudBackupFolder();
    if (folderId == null) return;

    final myTag = deviceTag(deviceId);
    final listedIds = {for (final f in files) f.id};
    final listedStems = {
      for (final f in files)
        if (parsePinMarker(f.name) == null) backupStem(f.name),
    };
    final here = await _cloudCopyCheck();
    final pinnedStems = <String>{};
    for (final r in _preferences.getHistory()) {
      final id = r.cloudFileId;
      if (!r.pinned || id == null || !here(r)) continue;
      if (listedIds.contains(id) ||
          listedStems.contains(backupStem(r.filename))) {
        pinnedStems.add(backupStem(r.filename));
      }
    }

    final myMarkers = <String, CloudFileInfo>{
      for (final f in files)
        if (parsePinMarker(f.name) case final m? when m.deviceTag == myTag)
          m.backupStem: f,
    };
    var changed = false;
    try {
      for (final stem in pinnedStems.difference(myMarkers.keys.toSet())) {
        await provider.uploadFile(
          Uint8List(0),
          pinMarkerName(backupFilename: stem, pinningDeviceId: deviceId),
          folderId: folderId,
        );
        changed = true;
      }
      for (final entry in myMarkers.entries) {
        if (pinnedStems.contains(entry.key)) continue;
        await provider.deleteFile(entry.value.id);
        changed = true;
      }
    } catch (e, st) {
      _log.warning(
        'Pin markers not reconciled; retried next prune',
        error: e,
        stackTrace: st,
      );
    }
    if (changed) await _flushQuietly(provider);
  }

  /// The key the switch stores for the folder backups go to now: the copy
  /// account's id, or `''` when it cannot be read.
  Future<String> crossDeviceRetentionAccountKey() async =>
      await _copyAccountIdOrNull() ?? '';

  /// Whether "count backups from all devices" is on for the folder backups
  /// go to now. Off for any other folder, including one a scheduled backup
  /// resolves differently, until the diver confirms it there.
  Future<bool> crossDeviceRetentionActive() async =>
      _cloudProvider != null &&
      _preferences.getSettings().crossDeviceRetentionFor(
        await _copyAccountIdOrNull(),
      );

  /// What pruning the folder to [keepCount] across devices would remove
  /// now, or null when there is no folder to read or the listing fails.
  Future<CrossDeviceRetentionPlan?> previewCrossDeviceRetention(
    int keepCount,
  ) async {
    final files = await _listCloudFolder();
    if (files == null) return null;
    final here = await _cloudCopyCheck();
    final pinned = [
      for (final r in _preferences.getHistory())
        if (r.pinned && r.cloudFileId != null && here(r)) r,
    ];
    return planCrossDeviceRetention(
      listing: files,
      keepCount: keepCount,
      locallyPinnedStems: {for (final r in pinned) backupStem(r.filename)},
      locallyPinnedFileIds: {for (final r in pinned) r.cloudFileId!},
      thisDeviceId: await thisDeviceIdOrNull() ?? '',
      now: DateTime.now(),
    );
  }

  /// Deletes what [plan] lists from the cloud folder and returns how many
  /// backups are gone. The folder is listed once more first: a backup that
  /// has gained a pin marker since the plan is kept, and if that listing
  /// fails nothing is deleted. A backup already gone counts as deleted.
  ///
  /// Only cloud copies are deleted. A record in this device's history whose
  /// cloud copy went keeps its local copy, or is removed when it had none.
  Future<int> applyCrossDeviceRetention(CrossDeviceRetentionPlan plan) async {
    final provider = _cloudProvider;
    if (provider == null || (plan.isEmpty && plan.orphanMarkers.isEmpty)) {
      return 0;
    }
    final fresh = await _listCloudFolder();
    if (fresh == null) return 0;
    final liveIds = {for (final f in fresh) f.id};
    final pinnedNow = {
      for (final f in fresh) ?parsePinMarker(f.name)?.backupStem,
    };

    final gone = <String>{};
    for (final candidate in plan.toDelete) {
      final file = candidate.file;
      if (pinnedNow.contains(backupStem(file.name))) continue;
      if (!liveIds.contains(file.id)) {
        gone.add(file.id);
        continue;
      }
      try {
        await provider.deleteFile(file.id);
        gone.add(file.id);
      } catch (e, st) {
        if (!await _existsOrAssumeSo(provider, file.id)) {
          gone.add(file.id);
        } else {
          _log.warning(
            'Backup ${file.name} not removed; retried next prune',
            error: e,
            stackTrace: st,
          );
        }
      }
    }
    for (final marker in plan.orphanMarkers) {
      if (!liveIds.contains(marker.id)) continue;
      try {
        await provider.deleteFile(marker.id);
      } catch (e) {
        _log.warning('Orphan pin marker ${marker.name} not removed: $e');
      }
    }
    try {
      await flushDeferredWrites(provider);
    } catch (e, st) {
      // As for per-device pruning: nothing is gone until the push lands.
      _log.warning(
        'Cross-device prune not pushed; retried next prune',
        error: e,
        stackTrace: st,
      );
      return 0;
    }

    final here = await _cloudCopyCheck();
    for (final r in _preferences.getHistory()) {
      final id = r.cloudFileId;
      if (id == null || !gone.contains(id) || !here(r)) continue;
      if (r.localPath != null) {
        await _preferences.updateRecord(r.withoutCloudCopy());
      } else {
        await _preferences.removeRecord(r.id);
      }
    }
    if (gone.isNotEmpty) {
      _log.info('Removed ${gone.length} backups across devices');
    }
    return gone.length;
  }

  /// The cross-device step of [BackupService.pruneOldBackups]. Never throws.
  Future<void> _pruneAcrossDevices(int keepCount) async {
    try {
      if (!await crossDeviceRetentionActive()) return;
      final plan = await previewCrossDeviceRetention(keepCount);
      if (plan != null) await applyCrossDeviceRetention(plan);
    } catch (e, st) {
      _log.warning(
        'Cross-device prune failed; retried next prune',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Stems of backups a device other than this one has pinned, from the
  /// markers in [listing]. When this device's id is unknown every marker
  /// counts, so an unreadable id can only keep a copy, never lose one.
  Future<Set<String>> _stemsPinnedElsewhere(
    List<CloudFileInfo>? listing,
  ) async {
    if (listing == null) return const {};
    final id = await thisDeviceIdOrNull();
    final myTag = id == null ? null : deviceTag(id);
    return {
      for (final f in listing)
        if (parsePinMarker(f.name) case final m? when m.deviceTag != myTag)
          m.backupStem,
    };
  }

  /// Whether [fileId] is still in the folder; true when that cannot be told,
  /// so an unanswerable check never records a backup as gone.
  Future<bool> _existsOrAssumeSo(
    CloudStorageProvider provider,
    String fileId,
  ) async {
    try {
      return await provider.fileExists(fileId);
    } catch (_) {
      return true;
    }
  }

  /// The cloud backup folder's listing, or null when it cannot be read.
  /// Unlike [getCloudBackups], a failure is not an empty folder: a missing
  /// pin marker must never be inferred from a listing that failed.
  Future<List<CloudFileInfo>?> _listCloudFolder() async {
    final provider = _cloudProvider;
    if (provider == null) return null;
    try {
      if (!await provider.isAuthenticated()) return null;
      final folderId = await _getOrCreateCloudBackupFolder();
      if (folderId == null) return null;
      return await provider.listFiles(
        folderId: folderId,
        namePattern: 'submersion_backup_',
      );
    } catch (e, st) {
      _log.warning('Cloud backup folder unreadable', error: e, stackTrace: st);
      return null;
    }
  }

  /// Writes this device's marker for [record]. Never throws: the pin itself
  /// is in the ledger already, and reconciliation repairs a missing marker.
  Future<void> _writePinMarker(BackupRecord record) async {
    final provider = _cloudProvider;
    if (provider == null || record.cloudFileId == null) return;
    try {
      if (!await _cloudCopyHere(record)) return;
      final deviceId = await thisDeviceIdOrNull();
      if (deviceId == null) return;
      final folderId = await _getOrCreateCloudBackupFolder();
      if (folderId == null) return;
      await provider.uploadFile(
        Uint8List(0),
        pinMarkerName(
          backupFilename: record.filename,
          pinningDeviceId: deviceId,
        ),
        folderId: folderId,
      );
      await flushDeferredWrites(provider);
    } catch (e, st) {
      _log.warning(
        'Pin marker not written; retried next prune',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Deletes this device's marker for [record], if the folder has one.
  /// Never throws, as for [_writePinMarker].
  Future<void> _deletePinMarker(BackupRecord record) async {
    final provider = _cloudProvider;
    if (provider == null || record.cloudFileId == null) return;
    try {
      if (!await _cloudCopyHere(record)) return;
      final deviceId = await thisDeviceIdOrNull();
      if (deviceId == null) return;
      final name = pinMarkerName(
        backupFilename: record.filename,
        pinningDeviceId: deviceId,
      );
      final files = await _listCloudFolder() ?? const <CloudFileInfo>[];
      var deleted = false;
      for (final f in files.where((f) => f.name == name)) {
        await provider.deleteFile(f.id);
        deleted = true;
      }
      if (deleted) await flushDeferredWrites(provider);
    } catch (e, st) {
      _log.warning(
        'Pin marker not removed; retried next prune',
        error: e,
        stackTrace: st,
      );
    }
  }

  Future<void> _flushQuietly(CloudStorageProvider provider) async {
    try {
      await flushDeferredWrites(provider);
    } catch (e, st) {
      _log.warning('Cloud folder changes not pushed', error: e, stackTrace: st);
    }
  }
}
