part of 'library_restore_service.dart';

/// Shared documents in a restore (issue #4713). A backup holds their
/// records, never their page files, which stay in `pages/`.
extension _RestoreDocuments on LibraryRestoreService {
  /// The backup's document records by the id their file names: one that
  /// cannot be read, or names another id inside, is left out.
  static Map<String, LibraryDocumentRecord> _documentsIn(
    Map<String, Uint8List> opened,
  ) {
    const dir = '${SharedLibraryLayout.documentsDir}/document-';
    final out = <String, LibraryDocumentRecord>{};
    for (final e in opened.entries) {
      if (!e.key.startsWith(dir) || !e.key.endsWith('.json')) continue;
      final id = e.key.substring(dir.length, e.key.length - '.json'.length);
      try {
        final doc = LibraryDocumentRecord.decode(e.value);
        if (doc.id == id) out[id] = doc;
      } catch (err) {
        if (!SharedLibraryTransport.isUnreadable(err)) rethrow;
      }
    }
    return out;
  }

  Future<Map<String, LibraryDocumentRecord>> _provenDocuments(
    Map<String, LibraryDocumentRecord> docs,
    String libraryId,
    List<SharedLibraryRoles> signers,
  ) async {
    final ids = docs.keys.toList();
    final retired = <String, List<(String, int)>>{};
    for (final r in signers) {
      for (final e in r.retiredKeys.entries) {
        retired[e.key] = [...?retired[e.key], ...e.value];
      }
    }
    final checked = await dropUnverifiedAll(
      [
        for (final id in ids)
          (docs[id]!, LibraryDocumentRecord(id: id, siteId: docs[id]!.siteId)),
      ],
      libraryId: libraryId,
      approvedKeys: {for (final r in signers) ...r.editingKeys},
      retiredKeys: retired,
    );
    return {for (var k = 0; k < ids.length; k++) ids[k]: checked[k]};
  }

  /// Writes the backup's shared documents back with fresh clocks and
  /// tombstones the ones made since, as [_restoreSites] does for sites. A
  /// document whose page files are no longer in storage is left as the
  /// library holds it now. Returns how many were left so.
  Future<int> _restoreDocuments(
    SharedLibraryTransport t,
    String libraryId,
    String memberId,
    LibrarySigningKey key,
    Map<String, Uint8List> opened, {
    required List<SharedLibraryRoles> signers,
  }) async {
    final backedUp = _documentsIn(opened);
    final restored = await _provenDocuments(backedUp, libraryId, signers);
    final read = <String, LibraryDocumentRecord>{};
    for (final f in await t.listDocuments()) {
      final id = SharedLibraryTransport.documentIdOf(f);
      try {
        final doc = await t.readDocument(f.id);
        if (doc.id == id) read[id] = doc;
      } catch (e) {
        if (!SharedLibraryTransport.isUnreadable(e)) rethrow;
      }
    }
    final current = await _provenDocuments(read, libraryId, signers);
    final stored = {
      for (final f in await t.listPageFiles())
        SharedLibraryTransport.pageFileIdOf(f),
    };

    final clock = MemberClock(memberId, now: _nowMs);
    for (final doc in [...current.values, ...restored.values]) {
      for (final c in doc.clocks.values) {
        clock.receive(c.hlc);
      }
    }
    for (final s in (await _store.documentStates(libraryId)).values) {
      for (final c in s.clocks.values) {
        clock.receive(c.hlc);
      }
    }
    FieldClock stamp() => FieldClock(hlc: clock.next(), memberId: memberId);
    Object? cleared(String field) =>
        LibraryDocumentRecord.listFields.contains(field)
        ? const <Object?>[]
        : null;

    var missing = 0;
    for (final id in {...restored.keys, ...current.keys}) {
      if (!SharedLibraryTransport.isSafeFileId(id)) continue;
      final from = restored[id];
      final raw = backedUp[id];
      final now = current[id];
      if (from != null &&
          !from.deleted &&
          from.pageRefs.any((r) => !stored.contains(r.fileId))) {
        missing++;
        continue;
      }
      final names = {...?raw?.fields.keys, ...?now?.fields.keys};
      final doc = LibraryDocumentRecord(
        id: id,
        siteId: from?.siteId ?? now!.siteId,
        // A document made since the backup goes, keeping its fields.
        deleted: from?.deleted ?? true,
        fields: {
          for (final n in names)
            n: from == null
                ? now!.fields[n]
                : from.fields.containsKey(n)
                ? from.fields[n]
                : raw!.fields.containsKey(n) &&
                      (now?.fields.containsKey(n) ?? false)
                ? now!.fields[n]
                : cleared(n),
        },
        clocks: {
          if (from != null)
            for (final n in names) n: stamp(),
          if (from == null) ...?now?.clocks,
          LibraryDocumentRecord.deletedField: stamp(),
        },
        extra: from?.extra ?? now?.extra ?? const {},
      );
      await t.writeDocument(
        await signOwnFields(
          doc,
          libraryId: libraryId,
          memberId: memberId,
          key: key,
        ),
      );
    }
    return missing;
  }
}
