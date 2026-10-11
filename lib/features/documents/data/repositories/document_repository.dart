import 'package:collection/collection.dart';
import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/documents/data/repositories/document_row_mapper.dart';
import 'package:submersion/features/documents/domain/document_ids.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';
import 'package:submersion/core/services/notification_service.dart';

/// A document as the global list shows it.
class DocumentListEntry {
  final Document document;

  /// Name of the record the document is filed under; null when personal.
  final String? ownerLabel;
  final int pageCount;

  const DocumentListEntry(this.document, this.ownerLabel, this.pageCount);
}

typedef CardImages = ({Uint8List? front, Uint8List? back});

/// A document and its pages, captured before an undoable delete.
typedef DocumentSnapshotEntry = ({Document document, List<DocumentPage> pages});

/// The documents store (issue #2613): documents, their pages, and the two
/// read models other features build on (a diver's primary insurance and
/// latest clearance, a certification's card images).
class DocumentRepository {
  /// [cancelReminders] cancels a deleted document's expiry reminders; it
  /// defaults to the platform notifications (a no-op on desktop).
  DocumentRepository({
    Future<void> Function(String documentId)? cancelReminders,
  }) : _cancelReminders =
           cancelReminders ??
           NotificationService.instance.cancelDocumentReminders;

  final Future<void> Function(String documentId) _cancelReminders;

  /// Cancels the reminders of documents a caller deleted without going
  /// through this repository (the diver delete's raw steps).
  Future<void> cancelRemindersFor(Iterable<String> documentIds) async {
    for (final id in documentIds) {
      try {
        await _cancelReminders(id);
      } catch (e, stackTrace) {
        _log.warning(
          'Could not cancel reminders of document $id',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  AppDatabase get _db => DatabaseService.instance.database;
  final SyncRepository _syncRepository = SyncRepository();
  final _uuid = const Uuid();
  final _log = LoggerService.forClass(DocumentRepository);

  static const _docEntity = 'documents';

  /// Ids per `IN (...)` list, well under SQLite's bound-variable limit.
  static const _inListChunk = 500;
  static const _pageEntity = 'documentPages';

  Stream<void> watchChanges() => _db.tableUpdates(
    TableUpdateQuery.allOf([
      TableUpdateQuery.onTable(_db.documents),
      TableUpdateQuery.onTable(_db.documentPages),
    ]),
  );

  Future<Document?> getById(String id) async {
    final row = await (_db.select(
      _db.documents,
    )..where((t) => t.id.equals(id))).getSingleOrNull();
    return row == null ? null : documentFromRow(row);
  }

  /// The documents [owner] holds, optionally only [diverId]'s.
  Future<List<Document>> getForOwner(
    DocumentOwner owner, {
    String? diverId,
  }) async {
    if (!owner.isPersonal) {
      // Drift has no dynamic column lookup on the typed table; use SQL.
      final column = kDocumentOwnerColumns[owner.kind]!;
      return _db
          .customSelect(
            'SELECT * FROM documents WHERE $column = ? '
            '${diverId == null ? '' : 'AND diver_id = ? '}'
            'ORDER BY type, title, created_at',
            variables: [
              Variable.withString(owner.id!),
              if (diverId != null) Variable.withString(diverId),
            ],
            readsFrom: {_db.documents},
          )
          .map((r) => documentFromRow(_db.documents.map(r.data)))
          .get();
    }
    final q = _db.select(_db.documents)
      ..where(
        (t) =>
            t.diveId.isNull() &
            t.siteId.isNull() &
            t.tripId.isNull() &
            t.equipmentId.isNull() &
            t.courseId.isNull() &
            t.certificationId.isNull() &
            t.buddyId.isNull() &
            t.diveCenterId.isNull(),
      )
      ..orderBy([
        (t) => OrderingTerm(expression: t.type),
        (t) => OrderingTerm(expression: t.title),
        (t) => OrderingTerm(expression: t.createdAt),
      ]);
    if (diverId != null) q.where((t) => t.diverId.equals(diverId));
    return (await q.get()).map(documentFromRow).toList();
  }

  /// Every document of [diverId], with a display label for its owner.
  Future<List<DocumentListEntry>> getAllForDiver(String diverId) =>
      _entries('d.diver_id = ?', diverId);

  /// One document with its owner label, for the detail page.
  Future<DocumentListEntry?> getEntryById(String id) async =>
      (await _entries('d.id = ?', id)).firstOrNull;

  Future<List<DocumentListEntry>> _entries(String where, String arg) async {
    final rows = await _db
        .customSelect(
          'SELECT d.*, '
          '(SELECT COUNT(*) FROM document_pages p WHERE p.document_id = d.id) '
          'AS page_count, '
          'COALESCE(s.name, t.name, e.name, c.name, cert.name, b.name, '
          "dc.name, dv.name, '#' || dv.dive_number) AS owner_label "
          'FROM documents d '
          'LEFT JOIN dive_sites s ON s.id = d.site_id '
          'LEFT JOIN trips t ON t.id = d.trip_id '
          'LEFT JOIN equipment e ON e.id = d.equipment_id '
          'LEFT JOIN courses c ON c.id = d.course_id '
          'LEFT JOIN certifications cert ON cert.id = d.certification_id '
          'LEFT JOIN buddies b ON b.id = d.buddy_id '
          'LEFT JOIN dive_centers dc ON dc.id = d.dive_center_id '
          'LEFT JOIN dives dv ON dv.id = d.dive_id '
          'WHERE $where '
          'ORDER BY d.type, d.title, d.created_at',
          variables: [Variable.withString(arg)],
          readsFrom: {_db.documents, _db.documentPages},
        )
        .get();
    return [
      for (final r in rows)
        DocumentListEntry(
          documentFromRow(_db.documents.map(r.data)),
          r.readNullable<String>('owner_label'),
          r.read<int>('page_count'),
        ),
    ];
  }

  /// A document's pages in order. [withBytes] false reads every column but
  /// the content, so listing pages costs no BLOB reads.
  Future<List<DocumentPage>> getPages(
    String documentId, {
    bool withBytes = true,
  }) async {
    if (!withBytes) return _pagesWithoutBytes(documentId);
    final rows =
        await (_db.select(_db.documentPages)
              ..where((t) => t.documentId.equals(documentId))
              ..orderBy([(t) => OrderingTerm(expression: t.pageIndex)]))
            .get();
    return [for (final r in rows) pageFromRow(r)];
  }

  /// The first page, for a thumbnail: its content only when it is an
  /// image. A PDF, Word or text page shows an icon, so its (up to 10 MB)
  /// bytes are not read.
  Future<DocumentPage?> getFirstPage(String documentId) async {
    final page = (await _pagesWithoutBytes(documentId, limit: 1)).firstOrNull;
    if (page == null || !page.isImage) return page;
    return page.copyWith(bytes: await _pageBytes(page.id));
  }

  Future<List<DocumentPage>> _pagesWithoutBytes(
    String documentId, {
    int? limit,
  }) async {
    final t = _db.documentPages;
    final query = _db.selectOnly(t)
      ..addColumns([
        t.id,
        t.documentId,
        t.pageIndex,
        t.side,
        t.fileName,
        t.mimeType,
        t.sizeBytes,
        t.createdAt,
        t.updatedAt,
      ])
      ..where(t.documentId.equals(documentId))
      ..orderBy([OrderingTerm(expression: t.pageIndex)]);
    if (limit != null) query.limit(limit);
    return [
      for (final r in await query.get())
        DocumentPage(
          id: r.read(t.id)!,
          documentId: r.read(t.documentId)!,
          pageIndex: r.read(t.pageIndex)!,
          side: DocumentPageSide.fromStorage(r.read(t.side)),
          fileName: r.read(t.fileName)!,
          mimeType: r.read(t.mimeType)!,
          sizeBytes: r.read(t.sizeBytes)!,
          createdAt: DateTime.fromMillisecondsSinceEpoch(r.read(t.createdAt)!),
          updatedAt: DateTime.fromMillisecondsSinceEpoch(r.read(t.updatedAt)!),
        ),
    ];
  }

  Future<Uint8List?> _pageBytes(String pageId) =>
      (_db.selectOnly(_db.documentPages)
            ..addColumns([_db.documentPages.bytes])
            ..where(_db.documentPages.id.equals(pageId)))
          .map((r) => r.read(_db.documentPages.bytes))
          .getSingleOrNull();

  /// Saves [document] and makes [pages] its exact page list, in order: new
  /// pages (empty id) are inserted, kept pages updated only when changed,
  /// missing ones deleted and tombstoned. A page with no bytes keeps its
  /// stored content. One transaction.
  Future<Document> save(
    Document document,
    List<DocumentPage> pages, {
    bool notify = true,
  }) async {
    final now = DateTime.now();
    final nowMs = now.millisecondsSinceEpoch;
    final isNew = document.id.isEmpty;
    final id = isNew ? _uuid.v4() : document.id;
    final doc = document.copyWith(
      id: id,
      createdAt: isNew ? now : document.createdAt,
      updatedAt: now,
      isPrimary: document.type == DocumentType.insurance && document.isPrimary,
    );
    try {
      await _db.transaction(() async {
        if (doc.isPrimary) {
          await _clearOtherPrimaries(doc.diverId, id, nowMs);
        }
        await _db
            .into(_db.documents)
            .insertOnConflictUpdate(documentCompanion(doc, updatedAt: nowMs));
        await _syncRepository.markRecordPending(
          entityType: _docEntity,
          recordId: id,
          localUpdatedAt: nowMs,
        );
        await _replacePages(id, pages, nowMs);
      });
      if (notify) SyncEventBus.notifyLocalChange();
      return doc;
    } catch (e, stackTrace) {
      _log.error(
        'Failed to save document $id',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> _clearOtherPrimaries(
    String diverId,
    String keepId,
    int now,
  ) async {
    final others =
        await (_db.select(_db.documents)..where(
              (t) =>
                  t.diverId.equals(diverId) &
                  t.type.equals(DocumentType.insurance.storage) &
                  t.isPrimary.equals(true) &
                  t.id.equals(keepId).not(),
            ))
            .get();
    for (final o in others) {
      await (_db.update(_db.documents)..where((t) => t.id.equals(o.id))).write(
        DocumentsCompanion(
          isPrimary: const Value(false),
          updatedAt: Value(now),
        ),
      );
      await _syncRepository.markRecordPending(
        entityType: _docEntity,
        recordId: o.id,
        localUpdatedAt: now,
      );
    }
  }

  Future<void> _replacePages(
    String documentId,
    List<DocumentPage> pages,
    int now,
  ) async {
    // Without content: a stored page's bytes are read only to compare them
    // with a replacement of the same size.
    final existing = {
      for (final p in await _pagesWithoutBytes(documentId)) p.id: p,
    };
    final keptIds = <String>{};
    for (final (index, page) in pages.indexed) {
      final pageId = page.id.isEmpty ? _uuid.v4() : page.id;
      keptIds.add(pageId);
      final old = existing[pageId];
      final bytes = page.bytes;
      if (bytes == null && old == null) {
        throw ArgumentError('page $pageId has no content');
      }
      final contentChanged =
          bytes != null &&
          (old == null ||
              old.sizeBytes != bytes.length ||
              !const ListEquality<int>().equals(
                await _pageBytes(pageId),
                bytes,
              ));
      if (!contentChanged) {
        if (old!.pageIndex == index && old.side == page.side) continue;
        // Moved or relabelled: the stored content stays as it is.
        await (_db.update(
          _db.documentPages,
        )..where((t) => t.id.equals(pageId))).write(
          DocumentPagesCompanion(
            pageIndex: Value(index),
            side: Value(page.side?.name),
            updatedAt: Value(now),
          ),
        );
      } else {
        await _db
            .into(_db.documentPages)
            .insertOnConflictUpdate(
              DocumentPagesCompanion(
                id: Value(pageId),
                documentId: Value(documentId),
                pageIndex: Value(index),
                side: Value(page.side?.name),
                fileName: Value(page.fileName),
                mimeType: Value(page.mimeType),
                sizeBytes: Value(bytes.length),
                bytes: Value(bytes),
                createdAt: Value(old?.createdAt.millisecondsSinceEpoch ?? now),
                updatedAt: Value(now),
              ),
            );
      }
      await _syncRepository.markRecordPending(
        entityType: _pageEntity,
        recordId: pageId,
        localUpdatedAt: now,
      );
    }
    final gone = [
      for (final id in existing.keys)
        if (!keptIds.contains(id)) id,
    ];
    if (gone.isEmpty) return;
    await (_db.delete(_db.documentPages)..where((t) => t.id.isIn(gone))).go();
    await _syncRepository.logDeletions(
      entityType: _pageEntity,
      recordIds: gone,
    );
  }

  Future<void> delete(String id) async {
    await _db.transaction(() => _deleteIds([id]));
    SyncEventBus.notifyLocalChange();
  }

  /// Deletes and tombstones every document an owner holds. Owner delete
  /// paths call this inside their own transaction, before deleting the
  /// owner: the schema's SET NULL would otherwise turn the documents into
  /// personal ones, and no cascade writes a tombstone.
  Future<void> deleteForOwner(DocumentOwnerKind kind, String ownerId) =>
      deleteForOwners(kind, [ownerId]);

  Future<void> deleteForOwners(
    DocumentOwnerKind kind,
    List<String> ownerIds,
  ) async {
    final column = kDocumentOwnerColumns[kind];
    if (column == null) {
      throw ArgumentError.value(kind, 'kind', 'needs an owner kind');
    }
    if (ownerIds.isEmpty) return;
    await _deleteIds((await _ownersOf(kind, ownerIds)).keys.toList());
  }

  Future<void> _deleteIds(List<String> ids) async {
    if (ids.isEmpty) return;
    final pageIds = <String>[];
    for (final chunk in ids.slices(_inListChunk)) {
      pageIds.addAll(
        await (_db.selectOnly(_db.documentPages)
              ..addColumns([_db.documentPages.id])
              ..where(_db.documentPages.documentId.isIn(chunk)))
            .map((r) => r.read(_db.documentPages.id)!)
            .get(),
      );
      await (_db.delete(
        _db.documentPages,
      )..where((t) => t.documentId.isIn(chunk))).go();
      await (_db.delete(_db.documents)..where((t) => t.id.isIn(chunk))).go();
    }
    await _syncRepository.logDeletions(
      entityType: _pageEntity,
      recordIds: pageIds,
    );
    await _syncRepository.logDeletions(entityType: _docEntity, recordIds: ids);
    // Every delete path comes through here, owner deletes included, so a
    // deleted permit can never still announce its expiry.
    for (final id in ids) {
      try {
        await _cancelReminders(id);
      } catch (e, stackTrace) {
        _log.warning(
          'Could not cancel reminders of document $id',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }
  }

  /// Moves every document of [fromIds] to [toId], for a merge that is
  /// about to delete [fromIds]. Returns document id -> previous owner id,
  /// for [restoreOwners] on undo.
  Future<Map<String, String>> reassignOwner(
    DocumentOwnerKind kind,
    List<String> fromIds,
    String toId,
  ) async {
    final moves = await _ownersOf(kind, fromIds);
    await _setOwners(kind, {for (final id in moves.keys) id: toId});
    return moves;
  }

  /// Puts each document of [owners] (document id -> owner id) back under
  /// that owner: the undo of [reassignOwner].
  Future<void> restoreOwners(
    DocumentOwnerKind kind,
    Map<String, String> owners,
  ) => _setOwners(kind, owners);

  Future<Map<String, String>> _ownersOf(
    DocumentOwnerKind kind,
    List<String> ownerIds,
  ) async {
    final column = kDocumentOwnerColumns[kind];
    if (column == null) {
      throw ArgumentError.value(kind, 'kind', 'needs an owner kind');
    }
    final out = <String, String>{};
    // Chunked under SQLite's bound-variable limit: a bulk dive delete or
    // merge can pass thousands of ids (#1953).
    for (final chunk in ownerIds.slices(_inListChunk)) {
      final placeholders = List.filled(chunk.length, '?').join(', ');
      final rows = await _db
          .customSelect(
            'SELECT id, $column AS owner FROM documents '
            'WHERE $column IN ($placeholders)',
            variables: [for (final o in chunk) Variable.withString(o)],
          )
          .get();
      for (final r in rows) {
        out[r.read<String>('id')] = r.read<String>('owner');
      }
    }
    return out;
  }

  Future<void> _setOwners(
    DocumentOwnerKind kind,
    Map<String, String> owners,
  ) async {
    if (owners.isEmpty) return;
    final column = kDocumentOwnerColumns[kind]!;
    final now = DateTime.now().millisecondsSinceEpoch;
    await _db.transaction(() async {
      for (final MapEntry(key: id, value: ownerId) in owners.entries) {
        await _db.customStatement(
          'UPDATE documents SET $column = ?, updated_at = ? WHERE id = ?',
          [ownerId, now, id],
        );
        await _syncRepository.markRecordPending(
          entityType: _docEntity,
          recordId: id,
          localUpdatedAt: now,
        );
      }
    });
  }

  /// The documents of [ownerIds] with their pages, for an undoable delete
  /// to hand back to [restoreSnapshot].
  Future<List<DocumentSnapshotEntry>> captureForOwners(
    DocumentOwnerKind kind,
    List<String> ownerIds,
  ) async {
    final ids = (await _ownersOf(kind, ownerIds)).keys;
    return [
      for (final id in ids)
        if (await getById(id) case final doc?)
          (document: doc, pages: await getPages(id)),
    ];
  }

  /// Re-creates captured documents and pages after an undone delete. Each
  /// is saved with a fresh clock, which beats the delete's tombstones on
  /// every peer.
  ///
  /// The delete's own tombstones are dropped from the local log, as a media
  /// restore does, so the next publish does not carry both a live row and
  /// its tombstone.
  Future<void> restoreSnapshot(List<DocumentSnapshotEntry> snapshot) async {
    for (final entry in snapshot) {
      await save(entry.document, entry.pages);
      await _syncRepository.removeDeletion(
        entityType: _docEntity,
        recordId: entry.document.id,
      );
      for (final page in entry.pages) {
        await _syncRepository.removeDeletion(
          entityType: _pageEntity,
          recordId: page.id,
        );
      }
    }
  }

  /// Each diver's insurance for the emergency card and home chip: the one
  /// marked primary, else (none marked, as after the primary was deleted or
  /// before one was chosen) the most recently updated. Two marked primaries
  /// (a sync merge of two devices' edits) resolve to the newer, then by id.
  Future<Map<String, Document>> primaryInsuranceByDiver({
    String? diverId,
  }) async {
    final q = _db.select(_db.documents)
      ..where((t) => t.type.equals(DocumentType.insurance.storage))
      ..orderBy([
        (t) => OrderingTerm.desc(t.isPrimary),
        (t) => OrderingTerm.desc(t.updatedAt),
        (t) => OrderingTerm.desc(t.id),
      ]);
    if (diverId != null) q.where((t) => t.diverId.equals(diverId));
    final out = <String, Document>{};
    for (final row in await q.get()) {
      out.putIfAbsent(row.diverId, () => documentFromRow(row));
    }
    return out;
  }

  /// Whether [diverId] has an insurance explicitly marked primary.
  Future<bool> hasPrimaryInsurance(String diverId) async {
    final row =
        await (_db.select(_db.documents)
              ..where(
                (t) =>
                    t.diverId.equals(diverId) &
                    t.type.equals(DocumentType.insurance.storage) &
                    t.isPrimary.equals(true),
              )
              ..limit(1))
            .getSingleOrNull();
    return row != null;
  }

  /// The latest medical clearance expiry per diver.
  Future<Map<String, DateTime>> latestClearanceExpiryByDiver({
    String? diverId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT diver_id, MAX(expiry_date) AS e FROM documents '
          "WHERE type = 'medicalClearance' AND expiry_date IS NOT NULL "
          '${diverId == null ? '' : 'AND diver_id = ? '}'
          'GROUP BY diver_id',
          variables: [if (diverId != null) Variable.withString(diverId)],
          readsFrom: {_db.documents},
        )
        .get();
    return {
      for (final r in rows)
        r.read<String>('diver_id'): DateTime.fromMillisecondsSinceEpoch(
          r.read<int>('e'),
        ),
    };
  }

  /// The front and back images of each certification's card document.
  Future<Map<String, CardImages>> cardImagesFor(
    List<String> certificationIds,
  ) async {
    if (certificationIds.isEmpty) return const {};
    final docIds = {
      for (final c in certificationIds) documentCertificationCardId(c): c,
    };
    // Only the Front and Back pages: any other page the diver added to the
    // card (an e-card PDF, say) is not read.
    final pages = await (_db.select(
      _db.documentPages,
    )..where((t) => t.documentId.isIn(docIds.keys) & t.side.isNotNull())).get();
    final out = <String, CardImages>{};
    for (final p in pages) {
      final certId = docIds[p.documentId]!;
      final current = out[certId] ?? (front: null, back: null);
      out[certId] = switch (DocumentPageSide.fromStorage(p.side)) {
        DocumentPageSide.front => (front: p.bytes, back: current.back),
        DocumentPageSide.back => (front: current.front, back: p.bytes),
        null => current,
      };
    }
    return out;
  }

  /// Writes a certification's card images: only the Front and Back pages
  /// change. Any other page the diver added to the card document stays, in
  /// order. Null clears that side. The card document goes away only when
  /// nothing the diver added would be left: no other page, no title, no
  /// notes. Unchanged bytes write nothing, so a rename of the certification
  /// does not re-stamp its pages.
  Future<void> saveCardImages({
    required String certificationId,
    required String diverId,
    required Uint8List? front,
    required Uint8List? back,
    bool notify = true,
  }) async {
    final docId = documentCertificationCardId(certificationId);
    final existing = await getById(docId);
    final pages = existing == null
        ? const <DocumentPage>[]
        : await getPages(docId);
    final extras = [
      for (final p in pages)
        if (p.side == null) p,
    ];
    const eq = ListEquality<int>();
    Uint8List? current(DocumentPageSide s) =>
        pages.where((p) => p.side == s).firstOrNull?.bytes;
    if (existing != null &&
        eq.equals(current(DocumentPageSide.front), front) &&
        eq.equals(current(DocumentPageSide.back), back)) {
      return;
    }
    if (front == null && back == null) {
      if (existing == null) return;
      final keep =
          extras.isNotEmpty ||
          existing.title.trim().isNotEmpty ||
          existing.notes.trim().isNotEmpty;
      if (!keep) {
        await _db.transaction(() => _deleteIds([docId]));
        if (notify) SyncEventBus.notifyLocalChange();
        return;
      }
    }
    final now = DateTime.now();
    final doc =
        existing ??
        Document(
          id: docId,
          diverId: diverId,
          owner: DocumentOwner(
            DocumentOwnerKind.certification,
            certificationId,
          ),
          type: DocumentType.certificationCard,
          createdAt: now,
          updatedAt: now,
        );
    DocumentPage side(DocumentPageSide s, Uint8List bytes) => DocumentPage(
      id: documentCardPageId(docId, s),
      documentId: docId,
      pageIndex: 0,
      side: s,
      fileName: '${s.name}.jpg',
      mimeType: 'image/jpeg',
      sizeBytes: bytes.length,
      bytes: bytes,
      createdAt: now,
      updatedAt: now,
    );
    await save(doc, [
      if (front != null) side(DocumentPageSide.front, front),
      if (back != null) side(DocumentPageSide.back, back),
      ...extras,
    ], notify: notify);
  }

  /// [diverId]'s documents that can remind: an expiry date, not a card.
  Future<List<Document>> getRemindingForDiver(String diverId) async {
    final rows =
        await (_db.select(_db.documents)..where(
              (t) =>
                  t.diverId.equals(diverId) &
                  t.expiryDate.isNotNull() &
                  t.type.equals(DocumentType.certificationCard.storage).not(),
            ))
            .get();
    return rows.map(documentFromRow).toList();
  }
}
