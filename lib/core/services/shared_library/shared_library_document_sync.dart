part of 'shared_library_service.dart';

// Shared documents in a library sync (issue #4713): run after the site pass,
// so a document's site is known here before the document merges.

/// What the documents pass did, folded into the sync's result.
typedef _DocumentPass = ({
  int pulled,
  int pushed,
  bool readOnly,
  bool uploadAttempted,
});

/// Whether [now] (the document's state as it is) differs from [before] (as
/// the pull read it): an edit was saved in between.
bool _documentEditedSince(
  SharedDocumentState? before,
  SharedDocumentState? now,
) {
  if (before == null || now == null) return before != now;
  return before.deleted != now.deleted ||
      !const MapEquality<String, FieldClock>().equals(
        before.clocks,
        now.clocks,
      );
}

extension _DocumentSync on SharedLibraryService {
  /// The page files the backups listed in storage refer to (issue #4713).
  /// An unsigned index only keeps more files, never fewer, so its entries
  /// count here without a signature check.
  Future<Set<String>> _retainedPageFileIds(SharedLibraryTransport t) async {
    final Map<String, dynamic>? json;
    try {
      json = await t.readBackupIndex();
    } catch (e) {
      if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
      // Unreadable: it may name any file, so keep every one this time.
      return {
        for (final f in await t.listPageFiles())
          SharedLibraryTransport.pageFileIdOf(f),
      };
    }
    final entries = json?['entries'];
    final out = <String>{};
    for (final e in entries is List ? entries : const []) {
      if (e is! Map) continue;
      if (e['pageFileIds'] case final List ids) {
        out.addAll(ids.whereType<String>());
      }
      // The backup's own list, which an older owner app's rewrite of the
      // index leaves alone.
      final backupId = e['backupId'];
      if (backupId is String &&
          SharedLibraryLayout.isValidLibraryId(backupId)) {
        try {
          out.addAll(await t.readBackupPages(backupId) ?? const []);
        } catch (err) {
          if (!SharedLibraryTransport.isUnreadable(err)) rethrow;
          // Unreadable: it may name any file, so keep every one this time.
          return {
            for (final f in await t.listPageFiles())
              SharedLibraryTransport.pageFileIdOf(f),
          };
        }
      }
    }
    return out;
  }

  /// Page files no document refers to are collected after this long: a
  /// member's concurrent edit may still name one about to be dropped.
  static const _pageGrace = Duration(days: 30);

  Future<_DocumentPass> _syncDocuments(
    SharedLibraryTransport t,
    SharedLibrary library, {
    required SharedLibraryMembership membership,
    required String diverId,
    required SharedLibraryRoles judged,
    required Map<String, String> pendingKeys,
    required bool holdWrites,
    required bool readOnly,
    required SharedLibraryRole role,
  }) async {
    final libraryId = library.id;
    final pull = await _pullDocuments(
      t,
      libraryId,
      diverId: diverId,
      judged: judged,
      pendingKeys: pendingKeys,
    );
    var pushed = 0;
    var uploadAttempted = false;
    var refused = readOnly;
    // A reader's storage may refuse these folders, and its role refuses
    // them first: nothing of a reader's goes up.
    if (!refused && role != SharedLibraryRole.reader) {
      final push = await _pushDocuments(
        t,
        libraryId,
        membership: membership,
        judged: judged,
        pendingKeys: pendingKeys,
        files: pull.files,
        deferred: pull.deferred,
      );
      pushed = push.pushed;
      uploadAttempted = push.uploadAttempted;
      refused = push.readOnly;
    }
    if (!holdWrites && !refused && role != SharedLibraryRole.reader) {
      await _rewriteDocumentForms(t);
    }
    if (!holdWrites && !refused && role == SharedLibraryRole.owner) {
      await _collectPageFiles(t, libraryId, pull.files);
    }
    return (
      pulled: pull.pulled,
      pushed: pushed,
      readOnly: refused,
      uploadAttempted: uploadAttempted,
    );
  }

  Future<({int pulled, List<CloudFileInfo> files, Set<String> deferred})>
  _pullDocuments(
    SharedLibraryTransport t,
    String libraryId, {
    required String diverId,
    required SharedLibraryRoles judged,
    required Map<String, String> pendingKeys,
  }) async {
    final states = await _store.documentStates(libraryId);
    final files = await t.listDocuments();
    var pulled = 0;
    final deferred = <String>{};
    for (final f in files) {
      final id = SharedLibraryTransport.documentIdOf(f);
      final stamp = f.modifiedTime.toUtc().toIso8601String();
      if (states[id]?.remoteModifiedTime == stamp) continue;
      final LibraryDocumentRecord remote;
      try {
        remote = await t.readDocument(f.id);
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
        _log.warning('Skipping unreadable library document ${f.name}: $e');
        continue;
      }
      if (remote.id != id) {
        _log.warning('Library document ${f.name} names another id; skipped');
        continue;
      }
      final state = await _store.getDocumentState(id);
      final hasRow = await _isLibraryDocumentRow(id, libraryId);
      final local = await _localDocumentRecord(
        id,
        remote.siteId,
        state,
        hasRow,
      );
      final checked = await dropUnverified(
        remote,
        local: local,
        libraryId: libraryId,
        approvedKeys: judged.editingKeys,
        retiredKeys: judged.retiredKeys,
        pendingKeys: pendingKeys,
      );
      if (_documentEditedSince(state, await _store.getDocumentState(id))) {
        deferred.add(id);
        continue;
      }
      final changed = await _mergeRemoteDocument(
        libraryId,
        local: local,
        remote: checked,
        state: state,
        hasRow: hasRow,
        stamp: stamp,
        diverId: diverId,
        t: t,
      );
      // Not merged (a page file not fetched): its rows are not what the
      // folder holds, so this sync must not upload them over it.
      if (changed == null) {
        deferred.add(id);
      } else if (changed) {
        pulled++;
      }
    }
    return (pulled: pulled, files: files, deferred: deferred);
  }

  Future<bool> _isLibraryDocumentRow(String id, String libraryId) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.documents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row != null && row.sharedLibraryId == libraryId;
  }

  /// The local side of a merge: the rows as a record, or just the clocks
  /// when they are gone or a tombstone.
  Future<LibraryDocumentRecord> _localDocumentRecord(
    String id,
    String remoteSiteId,
    SharedDocumentState? state,
    bool hasRow,
  ) async {
    if (state == null) {
      return LibraryDocumentRecord(id: id, siteId: remoteSiteId);
    }
    if (hasRow && !state.deleted) return _documentBridge.build(id, state);
    return LibraryDocumentRecord(
      id: id,
      siteId: state.siteId,
      deleted: state.deleted,
      clocks: state.clocks,
    );
  }

  /// Folds [remote] into the local document. A document shows only on a
  /// library site this device holds, and only with every page: one whose
  /// site was deleted, or has not arrived, is recorded and waits; one whose
  /// pages cannot all be fetched is left for the next sync. Returns true
  /// when the local rows changed, and null when it was not merged at all.
  Future<bool?> _mergeRemoteDocument(
    String libraryId, {
    required LibraryDocumentRecord local,
    required LibraryDocumentRecord remote,
    required SharedDocumentState? state,
    required bool hasRow,
    required String stamp,
    required String diverId,
    required SharedLibraryTransport t,
  }) async {
    final id = remote.id;
    // The site a document is filed under never changes.
    final siteId = state?.siteId ?? remote.siteId;
    final outcome = mergeClockedRecords(local: local, remote: remote);
    final merged = outcome.merged;
    final newest = newestClockOf(merged.clocks.values);
    final base =
        state ??
        SharedDocumentState(
          documentId: id,
          libraryId: libraryId,
          siteId: siteId,
        );
    Future<void> record({required bool parked}) => _store.putDocumentState(
      base.copyWith(
        clocks: merged.clocks,
        deleted: merged.deleted,
        parked: parked,
        dirty: (state?.dirty ?? false) || outcome.needsUpload,
        remoteModifiedTime: stamp,
        lastEditorMemberId: newest?.memberId,
        lastEditedAtMs: newest?.hlc.physicalTime,
      ),
    );

    final siteState = await _store.getSiteState(siteId);
    final siteHere = await _isLibrarySiteRow(siteId, libraryId);
    if (merged.deleted || (siteState?.deleted ?? false) || !siteHere) {
      if (hasRow) await _documentStamper.removeLibraryRows(id);
      // Waits for its site: read again when the site arrives.
      await record(parked: !merged.deleted && siteState == null && !siteHere);
      return hasRow;
    }
    final fields = hasRow && !(state?.deleted ?? false)
        ? outcome.remoteWon
        : merged.fields.keys.toSet();
    // A new row needs its kind and its pages: a record whose fields did
    // not prove themselves has neither, and is recorded only.
    if (!hasRow &&
        (!merged.fields.containsKey('type') ||
            !merged.fields.containsKey('pages'))) {
      await record(parked: false);
      return false;
    }
    if (fields.isNotEmpty &&
        !await _documentBridge.mayAdopt(merged, libraryId)) {
      _log.warning('Library document $id would take over another row; skipped');
      await record(parked: false);
      return false;
    }
    if (fields.isNotEmpty) {
      final Map<String, Uint8List> bytes;
      if (fields.contains('pages')) {
        final fetched = await _fetchPages(t, id, merged.pageRefs);
        // Not every page could be fetched: nothing shows half a document.
        // The stamp is not recorded, so the next sync reads it again.
        if (fetched == null) return null;
        bytes = fetched;
      } else {
        bytes = const {};
      }
      await _documentBridge.apply(
        merged,
        libraryId: libraryId,
        vocabularyDiverId: diverId,
        pageBytesByFileId: bytes,
        fields: fields,
      );
    }
    await record(parked: false);
    return fields.isNotEmpty;
  }

  Future<bool> _isLibrarySiteRow(String siteId, String libraryId) async {
    final db = DatabaseService.instance.database;
    final row = await (db.select(
      db.diveSites,
    )..where((t) => t.id.equals(siteId))).getSingleOrNull();
    return row != null && row.sharedLibraryId == libraryId;
  }

  /// The bytes of each page in [refs] this device does not hold yet, each
  /// checked against the hash its signed record names. Null when one is
  /// missing, unreadable or does not match.
  Future<Map<String, Uint8List>?> _fetchPages(
    SharedLibraryTransport t,
    String documentId,
    List<LibraryPageRef> refs,
  ) async {
    final held = await _documentBridge.heldPageFileIds();
    final out = <String, Uint8List>{};
    for (final ref in refs) {
      if (held.contains(ref.fileId)) continue;
      final file = await t.findPageFile(ref.fileId);
      if (file == null) {
        _log.warning('Page file ${ref.fileId} of $documentId not there yet');
        return null;
      }
      final Uint8List bytes;
      try {
        bytes = await t.readPageFile(file.id);
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
        _log.warning('Unreadable page file ${ref.fileId}: $e');
        return null;
      }
      if (sha256Hex(bytes) != ref.sha256) {
        _log.warning('Page file ${ref.fileId} does not match its record');
        return null;
      }
      out[ref.fileId] = bytes;
    }
    return out;
  }

  Future<({int pushed, bool readOnly, bool uploadAttempted})> _pushDocuments(
    SharedLibraryTransport t,
    String libraryId, {
    required SharedLibraryMembership membership,
    required SharedLibraryRoles judged,
    required Map<String, String> pendingKeys,
    required List<CloudFileInfo> files,
    required Set<String> deferred,
  }) async {
    final dirty = await _store.dirtyDocuments(libraryId);
    if (dirty.isEmpty) {
      return (pushed: 0, readOnly: false, uploadAttempted: false);
    }
    final localKeys = {
      for (final m in await _store.membershipsForLibrary(libraryId))
        m.memberId: m.signingKey ?? await _store.ensureSigningKey(m.diverId),
    };
    final remoteFiles = {
      for (final f in files) SharedLibraryTransport.documentIdOf(f): f.id,
    };
    final stored = {
      for (final f in await t.listPageFiles())
        SharedLibraryTransport.pageFileIdOf(f),
    };
    var pushed = 0;
    var uploadAttempted = false;
    for (final state in dirty) {
      if (deferred.contains(state.documentId)) continue;
      if (!SharedLibraryTransport.isSafeFileId(state.documentId)) continue;
      LibraryDocumentRecord doc;
      if (state.deleted) {
        doc = LibraryDocumentRecord(
          id: state.documentId,
          siteId: state.siteId,
          deleted: true,
          clocks: state.clocks,
        );
      } else {
        try {
          doc = await _documentBridge.build(state.documentId, state);
        } on StateError {
          // The rows are gone and no tombstone was recorded: nothing to send.
          await _store.deleteDocumentState(state.documentId);
          continue;
        }
      }
      try {
        uploadAttempted = true;
        // The pages first: a record never names a file that is not there.
        if (!doc.deleted) {
          for (final ref in doc.pageRefs) {
            if (stored.contains(ref.fileId)) continue;
            final bytes = await _documentBridge.heldPageBytes(ref.fileId);
            if (bytes == null) continue;
            await t.writePageFile(ref.fileId, bytes);
            stored.add(ref.fileId);
          }
        }
        var carried = const <String, FieldClock?>{};
        final remoteId = remoteFiles[state.documentId];
        final othersSigned = doc.clocks.values.any(
          (c) => !localKeys.containsKey(c.memberId),
        );
        if (remoteId != null &&
            (state.deleted || pendingKeys.isNotEmpty || othersSigned)) {
          try {
            final remote = await t.readDocument(remoteId);
            doc = await _authorsValues(
              doc,
              remote,
              localKeys.keys.toSet(),
              libraryId: libraryId,
              keys: {...pendingKeys, ...judged.editingKeys},
              retiredKeys: judged.retiredKeys,
            );
            if (state.deleted) {
              // A tombstone keeps the record's fields, so the document
              // could come back intact.
              final proven = await dropUnverified(
                remote,
                local: doc,
                libraryId: libraryId,
                approvedKeys: judged.editingKeys,
                retiredKeys: judged.retiredKeys,
              );
              doc = mergeClockedRecords(local: doc, remote: proven).merged;
            }
            final before = doc.clocks;
            doc = await carryHeld(
              doc,
              remote,
              libraryId: libraryId,
              pendingKeys: pendingKeys,
            );
            carried = {
              for (final e in doc.clocks.entries)
                if (before[e.key]?.hlc != e.value.hlc) e.key: before[e.key],
            };
          } catch (e) {
            if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
          }
        }
        doc = _claimUnattributed(doc, membership.memberId);
        for (final e in localKeys.entries) {
          doc = await signOwnFields(
            doc,
            libraryId: libraryId,
            memberId: e.key,
            key: e.value,
          );
        }
        final modified = await t.writeDocument(doc);
        await _recordDocumentUpload(
          state,
          modified,
          uploaded: doc,
          carried: carried,
        );
        pushed++;
      } catch (e) {
        if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
        _log.warning('Library $libraryId refused a document: read-only');
        return (pushed: pushed, readOnly: true, uploadAttempted: true);
      }
    }
    return (pushed: pushed, readOnly: false, uploadAttempted: uploadAttempted);
  }

  /// Marks [sent] uploaded at [modified], as `_recordUpload` does for sites.
  Future<void> _recordDocumentUpload(
    SharedDocumentState sent,
    DateTime? modified, {
    required LibraryDocumentRecord uploaded,
    Map<String, FieldClock?> carried = const {},
  }) async {
    final current = await _store.getDocumentState(sent.documentId) ?? sent;
    final editedMeanwhile = _documentEditedSince(sent, current);
    final recorded = {
      for (final e in uploaded.clocks.entries)
        if (!carried.containsKey(e.key))
          e.key: e.value
        else
          e.key: ?carried[e.key],
    };
    await _store.putDocumentState(
      current.copyWith(
        clocks: editedMeanwhile ? null : recorded,
        dirty: editedMeanwhile,
        remoteModifiedTime: modified?.toUtc().toIso8601String(),
        clearRemoteModifiedTime: modified == null,
      ),
    );
  }

  /// Document and page files read in the wrong form (an older owner app
  /// turned encryption on or off): any editor rewrites them, not only an
  /// owner, so they never wait on an owner who still holds the old key.
  Future<void> _rewriteDocumentForms(SharedLibraryTransport t) async {
    for (final e in {...t.mismatched}.entries) {
      final dir = e.key.split('/').first;
      if (dir != SharedLibraryLayout.documentsDir &&
          dir != SharedLibraryLayout.pagesDir) {
        continue;
      }
      try {
        await t.rewrite(e.key, e.value);
        t.mismatched.remove(e.key);
      } catch (err) {
        if (!SharedLibraryTransport.isPermissionError(err)) rethrow;
      }
    }
  }

  /// Deletes page files no document and no kept backup refers to, once
  /// they are older than [_pageGrace]. Most syncs find nothing old and
  /// unknown to this device's rows, and read no document to decide.
  Future<void> _collectPageFiles(
    SharedLibraryTransport t,
    String libraryId,
    List<CloudFileInfo> documentFiles,
  ) async {
    final cutoff = _now().toUtc().subtract(_pageGrace);
    final held = await _documentBridge.heldPageFileIds(libraryId: libraryId);
    final candidates = [
      for (final f in await t.listPageFiles())
        if (f.modifiedTime.toUtc().isBefore(cutoff) &&
            !held.contains(SharedLibraryTransport.pageFileIdOf(f)))
          f,
    ];
    if (candidates.isEmpty) return;
    final referenced = <String>{...await _retainedPageFileIds(t)};
    for (final f in documentFiles) {
      try {
        final doc = await t.readDocument(f.id);
        if (doc.deleted) continue;
        referenced.addAll(doc.pageRefs.map((r) => r.fileId));
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
        // A record this device cannot read may name any file: keep them all.
        return;
      }
    }
    for (final f in candidates) {
      if (referenced.contains(SharedLibraryTransport.pageFileIdOf(f))) {
        continue;
      }
      try {
        await t.deletePageFile(f.id);
      } catch (e) {
        if (!SharedLibraryTransport.isPermissionError(e)) rethrow;
        return;
      }
    }
  }
}
