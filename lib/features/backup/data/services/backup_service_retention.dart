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
  ///
  /// [deviceId] is this device's id when the caller has already read it.
  Future<void> reconcilePinMarkers({
    List<CloudFileInfo>? listing,
    String? deviceId,
  }) async {
    final provider = _cloudProvider;
    if (provider == null) return;
    deviceId ??= await thisDeviceIdOrNull();
    if (deviceId == null) return;
    final here = await _cloudCopyCheck();
    final state = _pinMarkerState(here, await crossDeviceRetentionAccountKey());
    final files = listing ?? await _listCloudFolder();
    if (files == null) return;

    final myTag = deviceTag(deviceId);
    final listedIds = {for (final f in files) f.id};
    final listedStems = {
      for (final f in files)
        if (parsePinMarker(f.name) == null) backupStem(f.name),
    };
    final pinnedStems = <String>{};
    for (final r in _preferences.getHistory()) {
      final id = r.cloudFileId;
      if (!r.pinned || id == null || !here(r)) continue;
      if (listedIds.contains(id) ||
          listedStems.contains(backupStem(r.filename))) {
        pinnedStems.add(backupStem(r.filename));
      }
    }

    // A backend that allows duplicate names (Google Drive) can hold two of
    // this device's markers for one backup; all but one go.
    final kept = <String>{};
    final toDelete = <CloudFileInfo>[];
    for (final f in files) {
      final m = parsePinMarker(f.name);
      if (m == null || m.deviceTag != myTag) continue;
      if (pinnedStems.contains(m.backupStem) && kept.add(m.backupStem)) {
        continue;
      }
      toDelete.add(f);
    }
    final toWrite = pinnedStems.difference(kept);

    try {
      if (toWrite.isNotEmpty) {
        final folderId = await _getOrCreateCloudBackupFolder();
        if (folderId == null) return;
        for (final stem in toWrite) {
          await provider.uploadFile(
            Uint8List(0),
            pinMarkerName(backupFilename: stem, pinningDeviceId: deviceId),
            folderId: folderId,
          );
        }
      }
      for (final f in toDelete) {
        await provider.deleteFile(f.id);
      }
      if (toWrite.isNotEmpty || toDelete.isNotEmpty) {
        await flushDeferredWrites(provider);
      }
      // A pinned copy the listing did not show yet got no marker: leave the
      // state unrecorded so the next prune tries again.
      if (pinnedStems.containsAll(state.stems)) {
        await _preferences.setPinMarkersSynced(state.encoded);
      }
    } catch (e, st) {
      _log.warning(
        'Pin markers not reconciled; retried next prune',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// The key the switch stores for the folder backups go to now: the copy
  /// account's id, or the provider's when the account cannot be read. Never
  /// empty, so two unknown accounts on different services cannot match.
  Future<String> crossDeviceRetentionAccountKey() async =>
      await _copyAccountIdOrNull() ??
      'provider:${_cloudProvider?.providerId ?? ''}';

  /// Whether "count backups from all devices" is on for the folder backups
  /// go to now. Off while cloud backup is off (the provider then only follows
  /// sync), and off for any other folder, including one a scheduled backup
  /// resolves differently, until the diver confirms it there.
  Future<bool> crossDeviceRetentionActive() async =>
      _crossDeviceRetentionActiveFor(await crossDeviceRetentionAccountKey());

  /// [crossDeviceRetentionActive] for a folder key already read.
  bool _crossDeviceRetentionActiveFor(String folderKey) {
    if (_cloudProvider == null) return false;
    final settings = _preferences.getSettings();
    return settings.cloudBackupEnabled &&
        settings.crossDeviceRetentionFor(folderKey);
  }

  /// What pruning the folder to [keepCount] across devices would remove
  /// now, or null when there is no folder to read or the listing fails.
  Future<CrossDeviceRetentionPlan?> previewCrossDeviceRetention(
    int keepCount, {
    List<CloudFileInfo>? listing,
  }) async {
    final files = listing ?? await _listCloudFolder();
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
  /// fails nothing is deleted. A backup that listing no longer shows counts
  /// as deleted; one whose delete fails does not.
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
        // Not gone until a listing says so: some services answer "missing"
        // to an existence check that merely failed. Retried next prune.
        _log.warning(
          'Backup ${file.name} not removed; retried next prune',
          error: e,
          stackTrace: st,
        );
      }
    }
    final freshStems = {
      for (final f in fresh)
        if (parsePinMarker(f.name) == null) backupStem(f.name),
    };
    for (final marker in plan.orphanMarkers) {
      if (!liveIds.contains(marker.id)) continue;
      // Its backup arrived after the plan was made: a live pin now.
      final m = parsePinMarker(marker.name);
      if (m != null && freshStems.contains(m.backupStem)) continue;
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

  /// The cross-device step of [BackupServicePruning.pruneOldBackups], planned
  /// from [listing] (the prune's own, less what it just deleted). Never
  /// throws.
  Future<void> _pruneAcrossDevices(
    int keepCount, {
    required List<CloudFileInfo> listing,
  }) async {
    try {
      final plan = await previewCrossDeviceRetention(
        keepCount,
        listing: listing,
      );
      if (plan != null) await applyCrossDeviceRetention(plan);
    } catch (e, st) {
      _log.warning(
        'Cross-device prune failed; retried next prune',
        error: e,
        stackTrace: st,
      );
    }
  }

  /// Whether this device's markers may not match its pins: true when the
  /// pinned cloud copies differ from those the last reconcile recorded for
  /// this folder. False with no device id, since nothing could be written.
  bool _pinMarkersStale(
    bool Function(BackupRecord) here,
    String folderKey, {
    required String? deviceId,
  }) {
    if (_cloudProvider == null || deviceId == null) return false;
    final recorded = _preferences.getPinMarkersSynced();
    final current = _pinMarkerState(here, folderKey);
    // Never reconciled and nothing pinned: there is nothing to mirror.
    if (recorded == null) return current.stems.isNotEmpty;
    return recorded != current.encoded;
  }

  /// The stems of this device's pinned cloud copies in [folderKey]'s folder,
  /// and the two as one string to compare with what a reconcile recorded.
  ({List<String> stems, String encoded}) _pinMarkerState(
    bool Function(BackupRecord) here,
    String folderKey,
  ) {
    final stems = [
      for (final r in _preferences.getHistory())
        if (r.pinned && r.cloudFileId != null && here(r))
          backupStem(r.filename),
    ]..sort();
    return (stems: stems, encoded: [folderKey, ...stems].join('\n'));
  }

  /// Stems of backups a device other than this one has pinned, from the
  /// markers in [listing]. When this device's id is unknown every marker
  /// counts, so an unreadable id can only keep a copy, never lose one.
  Set<String> _stemsPinnedElsewhere(
    List<CloudFileInfo>? listing, {
    required String? deviceId,
  }) {
    if (listing == null) return const {};
    final myTag = deviceId == null ? null : deviceTag(deviceId);
    return {
      for (final f in listing)
        if (parsePinMarker(f.name) case final m? when m.deviceTag != myTag)
          m.backupStem,
    };
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
        namePattern: backupFilePrefix,
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
      final name = pinMarkerName(
        backupFilename: record.filename,
        pinningDeviceId: deviceId,
      );
      // No listing first: a duplicate on a backend that allows two files of
      // one name is harmless, and reconciliation removes it.
      final folderId = await _getOrCreateCloudBackupFolder();
      if (folderId == null) return;
      await provider.uploadFile(Uint8List(0), name, folderId: folderId);
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
}
