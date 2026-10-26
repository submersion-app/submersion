part of 'sync_service.dart';

/// What a replace and join (issue #3482, spec section 6.4.1) came to.
enum ReplaceJoinOutcome {
  /// This device's library is now the account's.
  replaced,

  /// The account holds no library this device can read.
  noLibrary,

  /// The library is being replaced from another device and its new copy has
  /// not finished uploading; try again once it has.
  stillUploading,

  /// A device published the library from a newer schema; this build must
  /// update first, or it would drop what it cannot read.
  newerSchema,

  /// The library is encrypted and this device holds no key for it yet.
  needsPassphrase,

  /// A photo transfer was still finishing; nothing changed. Try again in a
  /// moment.
  photosBusy,
}

class ReplaceJoinResult {
  const ReplaceJoinResult(this.outcome, {this.newerSchemaPeerNames = const {}});

  final ReplaceJoinOutcome outcome;

  /// The devices that published from a newer schema, by id, for
  /// [ReplaceJoinOutcome.newerSchema].
  final Map<String, String> newerSchemaPeerNames;
}

/// The account's library, downloaded and checked, with nothing changed on
/// this device yet. [dispose] deletes its downloaded files; applying it
/// does too.
class ReplaceJoinPrepared {
  ReplaceJoinPrepared._(
    this._sink, {
    required this.marker,
    required this.baseFilePaths,
    required this.baseExportedAt,
    required this.changesets,
    required this.cursors,
  });

  /// A library with nothing in it, for tests of the steps around the
  /// replace.
  @visibleForTesting
  factory ReplaceJoinPrepared.empty() => ReplaceJoinPrepared._(
    BasePartFileSink(),
    marker: null,
    baseFilePaths: const [],
    baseExportedAt: const [],
    changesets: const [],
    cursors: const [],
  );

  final BasePartFileSink _sink;

  /// The library's current epoch, or null for a library never replaced.
  final LibraryEpochMarker? marker;
  final List<String> baseFilePaths;
  final List<int> baseExportedAt;
  final List<SyncPayload> changesets;
  final List<({String deviceId, int baseSeq, int appliedThrough})> cursors;

  bool _disposed = false;

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    for (final path in baseFilePaths) {
      await _sink.deleteQuietly(path);
    }
  }
}

/// Replace and join: this device's library is replaced by the one in its
/// sync account, the way a retired device rejoins (cloud wins), without
/// replaying anything local. Two calls, so the caller can take its backup
/// once the library is proven readable and before anything changes.
extension SyncServiceReplaceJoin on SyncService {
  /// Downloads and checks the account's library; changes nothing here.
  /// Exactly one of the two fields is set.
  Future<({ReplaceJoinPrepared? prepared, ReplaceJoinResult? refused})>
  prepareReplaceJoin() async {
    final provider = _cloudProvider;
    if (provider == null) {
      throw StateError('Replace and join needs a sync account');
    }
    const needsPassphrase = (
      prepared: null,
      refused: ReplaceJoinResult(ReplaceJoinOutcome.needsPassphrase),
    );
    final folderId = await provider.getOrCreateSyncFolder();
    final LibraryEpochMarker? marker;
    try {
      marker = await readLibraryEpochMarker(provider);
    } on SyncEncryptionRequired {
      return needsPassphrase;
    }
    final files = await provider.listFiles(
      folderId: folderId,
      namePattern: ChangesetLogLayout.prefix,
    );
    // A retired device's log may linger; pull never merges from it, and
    // neither does a rebuild (as the retirement fence does).
    final retired = <String>{
      for (final f in files)
        if (ChangesetLogLayout.isRetiredMarker(f.name) &&
            ChangesetLogLayout.deviceIdOf(f.name) != null)
          ChangesetLogLayout.deviceIdOf(f.name)!,
    };
    // The collector skips a manifest it cannot read, so a locked library
    // would look like no library at all: ask first. The manifests read here
    // also tell, after the collect, whether every device's copy arrived.
    final live = await _readLiveManifests(provider, files, retired);
    if (live.locked) return needsPassphrase;
    // This device's own log is part of the account's library: dives it
    // published before are its peers' too, and leaving them out would split
    // the fleet.
    final ({
      List<String> baseFilePaths,
      List<int> baseExportedAt,
      List<SyncPayload> changesets,
      List<({String deviceId, int baseSeq, int appliedThrough})> cursors,
      Set<String> newerSchemaPeerDeviceIds,
      Map<String, String> newerSchemaPeerNames,
    })
    sources;
    try {
      sources = await _collectEpochBaseSources(
        provider,
        folderId,
        marker?.epochId,
        excludeDeviceIds: retired,
      );
    } on SyncEncryptionRequired {
      return needsPassphrase;
    }
    if (sources.newerSchemaPeerDeviceIds.isNotEmpty) {
      return (
        prepared: null,
        refused: ReplaceJoinResult(
          ReplaceJoinOutcome.newerSchema,
          newerSchemaPeerNames: {
            for (final id in sources.newerSchemaPeerDeviceIds)
              id: sources.newerSchemaPeerNames[id] ?? id,
          },
        ),
      );
    }
    if (sources.baseFilePaths.isEmpty) {
      // A marker with no readable base for its epoch is a replace that has
      // not finished uploading, which adopt waits out too.
      return (
        prepared: null,
        refused: ReplaceJoinResult(
          marker == null
              ? ReplaceJoinOutcome.noLibrary
              : ReplaceJoinOutcome.stillUploading,
        ),
      );
    }
    final prepared = ReplaceJoinPrepared._(
      _baseSink,
      marker: marker,
      baseFilePaths: sources.baseFilePaths,
      baseExportedAt: sources.baseExportedAt,
      changesets: sources.changesets,
      cursors: sources.cursors,
    );
    // The collector skips a device whose copy has not fully arrived, which
    // a merge can wait out but a replace must not apply: refuse until every
    // device's copy is complete.
    if (_libraryIncomplete(live.manifests, marker?.epochId, sources.cursors)) {
      await prepared.dispose();
      return (
        prepared: null,
        refused: const ReplaceJoinResult(ReplaceJoinOutcome.stillUploading),
      );
    }
    return (prepared: prepared, refused: null);
  }

  /// Replaces this device's library with [prepared] in one transaction:
  /// the apply, this device's accounts the library lacks put back and
  /// marked to publish, and the sync bookkeeping re-based on the library
  /// (cursors, the adopted watermark, the accepted epoch and this account's
  /// last sync, so the Combine question is not asked again). An error before
  /// it commits leaves the database as it was and is rethrown; nothing
  /// after the commit throws. Always disposes [prepared].
  ///
  /// [afterApplyForTest] runs last inside the transaction; a throw there
  /// stands in for a crash mid-replace.
  Future<ReplaceJoinResult> applyReplaceJoin(
    ReplaceJoinPrepared prepared, {
    void Function()? afterApplyForTest,
  }) async {
    final provider = _cloudProvider;
    if (provider == null) {
      await prepared.dispose();
      throw StateError('Replace and join needs a sync account');
    }
    final db = DatabaseService.instance.database;
    final marker = prepared.marker;
    try {
      final roster = await db.select(db.connectedAccounts).get();
      await _serializer.applyInDeferredFkTransaction(() async {
        await _adoptApplyStreaming(
          baseFilePaths: prepared.baseFilePaths,
          baseExportedAt: prepared.baseExportedAt,
          changesets: prepared.changesets,
        );
        // The roster syncs, so the apply removed this device's accounts the
        // library has not seen yet. They are this device's, kept (spec
        // 6.4.1 step 4), and join the library's roster on the next sync.
        final present = {
          for (final row in await db.select(db.connectedAccounts).get()) row.id,
        };
        final kept = [
          for (final row in roster)
            if (!present.contains(row.id)) row,
        ];
        for (final row in kept) {
          await db.into(db.connectedAccounts).insert(row);
        }
        await _syncRepository.resetSyncState(clearDeletionLog: true);
        final cursorStore = PeerCursorStore(db);
        for (final c in prepared.cursors) {
          await cursorStore.upsert(
            peerDeviceId: c.deviceId,
            provider: provider.providerId,
            baseSeqApplied: c.baseSeq,
            lastSeqApplied: c.appliedThrough,
          );
        }
        // The library is exactly what its devices published, so this
        // device never uploads it again as its own base.
        await _publishStateStore.markAdoptedPendingBase(
          provider.providerId,
          await _syncRepository.maxRowHlc(),
        );
        // Always written, null included: an epoch this device accepted in
        // another library would otherwise be written back into this one.
        await _syncRepository.setLastAcceptedEpochId(marker?.epochId);
        await _syncRepository.updateLastSyncTime(
          DateTime.now(),
          providerId: provider.providerId,
        );
        // The clock reseeds from the library's newest row, so the kept
        // accounts sort above the adopted watermark and publish even when
        // the library's clocks ran ahead of this device's.
        SyncClock.instance.reset();
        final now = DateTime.now().millisecondsSinceEpoch;
        for (final row in kept) {
          await _syncRepository.markRecordPending(
            entityType: 'connectedAccounts',
            recordId: row.id,
            localUpdatedAt: now,
          );
        }
        afterApplyForTest?.call();
      });
    } finally {
      await prepared.dispose();
    }

    // Committed. The prefs mirrors follow the database, each on its own: a
    // stale pending replace left by a failed first write would run the old
    // replace on the next launch. A failure is logged, never reported as a
    // failed replace.
    for (final (name, write) in [
      ('accepted epoch', () async => _epochStore?.setLastAccepted(marker)),
      ('pending replace', () async => _epochStore?.clearPendingReplace()),
    ]) {
      try {
        await write();
      } catch (e, stackTrace) {
        _log.error(
          'Replace and join: could not update the $name mirror',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
    await _flushAfterRun('replace and join');
    _log.info('Replaced this device\'s library with the account\'s');
    return const ReplaceJoinResult(ReplaceJoinOutcome.replaced);
  }

  /// Whether a live device of [epochId] has published a base the collector
  /// could not assemble (no cursor for it), or changesets past the first
  /// gap it found (a cursor short of the manifest's head). Pull waits out
  /// both; a replace must not apply a library they leave short. A device
  /// with no base yet publishes changesets only, which pull applies on its
  /// own, so it does not count. [manifests] were read before the collect,
  /// so a device that published more since is measured against what it
  /// had then, which the collector's copy covers.
  bool _libraryIncomplete(
    Map<String, SyncManifest> manifests,
    String? epochId,
    List<({String deviceId, int baseSeq, int appliedThrough})> cursors,
  ) {
    final applied = {for (final c in cursors) c.deviceId: c.appliedThrough};
    for (final MapEntry(key: id, value: manifest) in manifests.entries) {
      if (manifest.epochId != epochId || manifest.baseSeq == null) continue;
      final through = applied[id];
      if (through == null || through < manifest.headSeq) return true;
    }
    return false;
  }

  /// Every live device's manifest among [files], read once, and whether any
  /// is an envelope this device cannot open. With the library key held, the
  /// provider decrypts on download and no envelope reaches here. A download
  /// that fails is rethrown, so a passing network error is never read as a
  /// device with nothing to check; a manifest that downloads but does not
  /// parse is left out, as pull and the collector skip it.
  Future<({bool locked, Map<String, SyncManifest> manifests})>
  _readLiveManifests(
    CloudStorageProvider provider,
    List<CloudFileInfo> files,
    Set<String> retired,
  ) async {
    final manifests = <String, SyncManifest>{};
    for (final f in files) {
      final id = ChangesetLogLayout.deviceIdOf(f.name);
      if (id == null || retired.contains(id)) continue;
      if (f.name != ChangesetLogLayout.manifestName(id)) continue;
      final Uint8List bytes;
      try {
        bytes = await provider.downloadFile(f.id);
      } on SyncEncryptionRequired {
        // Sealed under a key other than the one this device holds.
        return (locked: true, manifests: const <String, SyncManifest>{});
      }
      if (SyncEnvelope.hasMagic(bytes)) {
        return (locked: true, manifests: const <String, SyncManifest>{});
      }
      try {
        manifests[id] = SyncManifest.fromBytes(bytes);
      } catch (_) {
        // Unreadable: skipped by pull and the collector alike.
      }
    }
    return (locked: false, manifests: manifests);
  }
}
