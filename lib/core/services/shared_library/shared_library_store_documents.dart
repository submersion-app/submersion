part of 'shared_library_store.dart';

/// Per shared library document (issue #4713): field clocks, the dirty flag
/// and the stamp of the file as last read, the twin of the site states.
extension SharedLibraryStoreDocuments on SharedLibraryStore {
  Future<SharedDocumentState?> getDocumentState(String documentId) async {
    final row = await (_db.select(
      _db.sharedDocumentStates,
    )..where((t) => t.documentId.equals(documentId))).getSingleOrNull();
    return row == null ? null : _documentStateFromRow(row);
  }

  Future<List<SharedDocumentState>> dirtyDocuments(String libraryId) async {
    final rows =
        await (_db.select(_db.sharedDocumentStates)..where(
              (t) => t.libraryId.equals(libraryId) & t.dirty.equals(true),
            ))
            .get();
    return rows.map(_documentStateFromRow).toList();
  }

  Future<Map<String, SharedDocumentState>> documentStates(
    String libraryId,
  ) async {
    final rows = await (_db.select(
      _db.sharedDocumentStates,
    )..where((t) => t.libraryId.equals(libraryId))).get();
    return {for (final r in rows) r.documentId: _documentStateFromRow(r)};
  }

  Future<void> putDocumentState(SharedDocumentState s) => _db
      .into(_db.sharedDocumentStates)
      .insertOnConflictUpdate(
        SharedDocumentStatesCompanion.insert(
          documentId: s.documentId,
          libraryId: s.libraryId,
          siteId: s.siteId,
          clocksJson: Value(
            jsonEncode({
              for (final e in s.clocks.entries) e.key: e.value.toJson(),
            }),
          ),
          remoteModifiedTime: Value(s.remoteModifiedTime),
          dirty: Value(s.dirty),
          deleted: Value(s.deleted),
          parked: Value(s.parked),
          lastEditorMemberId: Value(s.lastEditorMemberId),
          lastEditedAtMs: Value(s.lastEditedAtMs),
        ),
      );

  Future<void> deleteDocumentState(String documentId) => (_db.delete(
    _db.sharedDocumentStates,
  )..where((t) => t.documentId.equals(documentId))).go();

  /// Forgets when [siteId]'s documents were last read, and that any waited
  /// for the site: the site has arrived or come back, so the next pull
  /// reads them all again.
  Future<void> clearDocumentStampsForSite(String siteId) =>
      (_db.update(
        _db.sharedDocumentStates,
      )..where((t) => t.siteId.equals(siteId))).write(
        const SharedDocumentStatesCompanion(
          remoteModifiedTime: Value(null),
          parked: Value(false),
        ),
      );

  Stream<void> watchDocumentStates() =>
      _db.tableUpdates(TableUpdateQuery.onTable(_db.sharedDocumentStates));

  SharedDocumentState _documentStateFromRow(SharedDocumentStateRow r) =>
      SharedDocumentState(
        documentId: r.documentId,
        libraryId: r.libraryId,
        siteId: r.siteId,
        clocks: _clocksFromJson(r.clocksJson),
        remoteModifiedTime: r.remoteModifiedTime,
        dirty: r.dirty,
        deleted: r.deleted,
        parked: r.parked,
        lastEditorMemberId: r.lastEditorMemberId,
        lastEditedAtMs: r.lastEditedAtMs,
      );
}
