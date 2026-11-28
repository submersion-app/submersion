import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/data/repositories/sync_repository.dart';
import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/library_edit_stamper.dart';
import 'package:submersion/core/services/shared_library/member_clock.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/core/services/shared_library/shared_library_models.dart';
import 'package:submersion/core/services/shared_library/shared_library_store.dart';
import 'package:submersion/core/services/sync/sync_event_bus.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';

/// The document types that start private even on a library site (issue
/// #4713): a diver's own papers rather than the library's.
const Set<DocumentType> _privateByDefault = {
  DocumentType.receipt,
  DocumentType.insurance,
  DocumentType.medicalClearance,
  DocumentType.certificationCard,
  DocumentType.booking,
};

/// Whether a new document of [type] on a library site starts private.
bool startsPrivateOnLibrarySite(DocumentType type) =>
    _privateByDefault.contains(type);

/// The id of the private copy [diverId] keeps when unsharing [documentId].
/// Deterministic, so the diver's devices make one copy, never the shared
/// id. The name string is frozen: changing it would fork every copy.
String unsharedDocumentId(String documentId, String diverId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:unshared-library-document:$diverId:$documentId',
);

/// The id of the private copy a shared document becomes when its site
/// leaves this device and is kept as a personal site. Frozen, as
/// [unsharedDocumentId] is.
String detachedDocumentId(String documentId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:detached-library-document:$documentId',
);

/// The id of page [pageId] in the private copy [copyId]: deterministic, so
/// the copies a diver's devices make on their own hold the same pages and
/// personal sync merges them instead of doubling them. Frozen, as
/// [unsharedDocumentId] is.
String privateCopyPageId(String copyId, String pageId) => const Uuid().v5(
  Namespace.url.value,
  'submersion:library-copy-page:$copyId:$pageId',
);

/// Records local edits to shared library documents (issue #4713), and moves
/// documents into and out of a library: the document twin of
/// [LibraryEditStamper]. A personal document is never touched.
class LibraryDocumentStamper {
  LibraryDocumentStamper({
    SharedLibraryStore? store,
    LibraryEditStamper? sites,
    DocumentRepository? documents,
    SyncRepository? sync,
  }) : _store = store ?? SharedLibraryStore(),
       _sites = sites ?? LibraryEditStamper(store: store),
       _documents = documents ?? DocumentRepository(),
       _sync = sync ?? SyncRepository();

  final SharedLibraryStore _store;
  final LibraryEditStamper _sites;
  final DocumentRepository _documents;
  final SyncRepository _sync;
  AppDatabase get _db => DatabaseService.instance.database;

  static const _docEntity = 'documents';
  static const _pageEntity = 'documentPages';
  static const _tagEntity = 'documentTags';

  Future<DocumentRow?> _row(String documentId) => (_db.select(
    _db.documents,
  )..where((t) => t.id.equals(documentId))).getSingleOrNull();

  /// Stamps [fields] on shared document [documentId] under the member
  /// [actingDiverId] edits as, and marks it for upload.
  Future<void> stamp(
    String documentId,
    Set<String> fields, {
    String? actingDiverId,
  }) async {
    if (fields.isEmpty) return;
    final row = await _row(documentId);
    final libraryId = row?.sharedLibraryId;
    if (row == null || libraryId == null) return;
    final existing = await _store.getDocumentState(documentId);
    final siteId = existing?.siteId ?? row.siteId;
    if (siteId == null) return;
    await _stampState(
      existing ??
          SharedDocumentState(
            documentId: documentId,
            libraryId: libraryId,
            siteId: siteId,
          ),
      fields,
      await _sites.resolveMember(libraryId, actingDiverId),
    );
  }

  Future<void> _stampState(
    SharedDocumentState existing,
    Set<String> fields,
    String memberId, {
    bool? deleted,
  }) async {
    final clock = MemberClock(memberId);
    for (final c in existing.clocks.values) {
      clock.receive(c.hlc);
    }
    final clocks = Map<String, FieldClock>.from(existing.clocks);
    for (final field in fields) {
      clocks[field] = FieldClock(hlc: clock.next(), memberId: memberId);
    }
    await _store.putDocumentState(
      existing.copyWith(
        clocks: clocks,
        dirty: true,
        deleted: deleted,
        lastEditorMemberId: memberId,
        lastEditedAtMs: DateTime.now().millisecondsSinceEpoch,
      ),
    );
  }

  /// Whether a write to [documentId] may go ahead here: always for a
  /// personal document; for a shared one, by the library's roles.
  Future<bool> mayEdit(String documentId, {String? actingDiverId}) async {
    final libraryId = (await _row(documentId))?.sharedLibraryId;
    if (libraryId == null) return true;
    return _sites.mayEditLibrary(libraryId, actingDiverId: actingDiverId);
  }

  /// The library of the site [siteId] is filed under, or null for a
  /// personal site.
  Future<String?> libraryOfSite(String siteId) async => (await (_db.select(
    _db.diveSites,
  )..where((t) => t.id.equals(siteId))).getSingleOrNull())?.sharedLibraryId;

  /// Shares the new document [documentId] when the default says so: it is
  /// filed on a library site, its type is not one that starts private, and
  /// [actingDiverId] may edit that library. Returns whether it was shared.
  Future<bool> shareIfDefault(
    String documentId, {
    required String actingDiverId,
  }) async {
    final row = await _row(documentId);
    final siteId = row?.siteId;
    if (row == null || siteId == null || row.sharedLibraryId != null) {
      return false;
    }
    if (startsPrivateOnLibrarySite(DocumentType.fromStorage(row.type))) {
      return false;
    }
    final libraryId = await libraryOfSite(siteId);
    if (libraryId == null) return false;
    if (!await _sites.mayEditLibrary(libraryId, actingDiverId: actingDiverId)) {
      return false;
    }
    await share(documentId, libraryId: libraryId, actingDiverId: actingDiverId);
    return true;
  }

  /// Turns the personal document [documentId], filed on a site of
  /// [libraryId], into the library's: same id, no diver, every field
  /// clocked under the member. Its personal-sync rows are tombstoned, so
  /// the diver's other devices drop their copy and receive the library's.
  Future<void> share(
    String documentId, {
    required String libraryId,
    String? actingDiverId,
  }) async {
    final row = await _row(documentId);
    final siteId = row?.siteId;
    if (row == null || siteId == null) {
      throw StateError('document $documentId is not filed on a site');
    }
    if (await libraryOfSite(siteId) != libraryId) {
      throw ArgumentError.value(libraryId, 'libraryId', 'not the site\'s');
    }
    final pageIds =
        await (_db.selectOnly(_db.documentPages)
              ..addColumns([_db.documentPages.id])
              ..where(_db.documentPages.documentId.equals(documentId)))
            .map((r) => r.read(_db.documentPages.id)!)
            .get();
    final linkIds =
        await (_db.selectOnly(_db.documentTags)
              ..addColumns([_db.documentTags.id])
              ..where(_db.documentTags.documentId.equals(documentId)))
            .map((r) => r.read(_db.documentTags.id)!)
            .get();
    await _db.transaction(() async {
      await (_db.update(
        _db.documents,
      )..where((t) => t.id.equals(documentId))).write(
        DocumentsCompanion(
          diverId: const Value(null),
          sharedLibraryId: Value(libraryId),
          isPrimary: const Value(false),
        ),
      );
      await _sync.logDeletions(entityType: _docEntity, recordIds: [documentId]);
      await _sync.logDeletions(entityType: _pageEntity, recordIds: pageIds);
      await _sync.logDeletions(entityType: _tagEntity, recordIds: linkIds);
    });
    // Cancels the reminders it no longer has.
    await _documents.cancelRemindersFor([documentId]);
    final existing = await _store.getDocumentState(documentId);
    await _stampState(
      existing?.copyWith(deleted: false) ??
          SharedDocumentState(
            documentId: documentId,
            libraryId: libraryId,
            siteId: siteId,
          ),
      {...LibraryDocumentRecord.fieldNames, LibraryDocumentRecord.deletedField},
      await _sites.resolveMember(libraryId, actingDiverId),
      deleted: false,
    );
    SyncEventBus.notifyLocalChange();
  }

  /// Stops sharing [documentId]: its library file gets a tombstone, so every
  /// other member loses it on their next sync, and [actingDiverId] keeps a
  /// private copy (pages and tags too) under [unsharedDocumentId]. Returns
  /// the copy's id.
  Future<String> unshare(
    String documentId, {
    required String actingDiverId,
  }) async {
    final row = await _row(documentId);
    final libraryId = row?.sharedLibraryId;
    final document = await _documents.getById(documentId);
    if (row == null || libraryId == null || document == null) {
      throw StateError('document $documentId is not shared');
    }
    final copyId = unsharedDocumentId(documentId, actingDiverId);
    await _keepPrivateCopy(document, copyId, actingDiverId);
    final existing =
        await _store.getDocumentState(documentId) ??
        SharedDocumentState(
          documentId: documentId,
          libraryId: libraryId,
          siteId: row.siteId ?? document.owner.id ?? '',
        );
    await _stampState(
      existing,
      {LibraryDocumentRecord.deletedField},
      await _sites.resolveMember(libraryId, actingDiverId),
      deleted: true,
    );
    await removeLibraryRows(documentId);
    SyncEventBus.notifyLocalChange();
    return copyId;
  }

  /// Removes shared document [documentId] from its library: a tombstone
  /// clocked under [actingDiverId]'s member goes up with the next sync, and
  /// the local rows go now, with no personal tombstone.
  Future<void> removeFromLibrary(
    String documentId, {
    String? actingDiverId,
  }) async {
    final row = await _row(documentId);
    final libraryId = row?.sharedLibraryId;
    if (row == null || libraryId == null) {
      throw StateError('document $documentId is not shared');
    }
    final existing =
        await _store.getDocumentState(documentId) ??
        SharedDocumentState(
          documentId: documentId,
          libraryId: libraryId,
          siteId: row.siteId ?? '',
        );
    await _stampState(
      existing,
      {LibraryDocumentRecord.deletedField},
      await _sites.resolveMember(libraryId, actingDiverId),
      deleted: true,
    );
    await removeLibraryRows(documentId);
    SyncEventBus.notifyLocalChange();
  }

  /// Saves [document]'s rows as [diverId]'s personal document [copyId],
  /// pages and tags included, for personal sync to carry. A copy already
  /// here (another device of the diver made it first) is kept as it is.
  Future<void> _keepPrivateCopy(
    Document document,
    String copyId,
    String diverId,
  ) async {
    if (await _documents.getById(copyId) != null) return;
    final pages = await _documents.getPages(document.id);
    final tagIds = [
      for (final r
          in await (_db.selectOnly(_db.documentTags)
                ..addColumns([_db.documentTags.tagId])
                ..where(_db.documentTags.documentId.equals(document.id)))
              .get())
        r.read(_db.documentTags.tagId)!,
    ];
    await _documents.save(
      document.copyWith(id: copyId, diverId: diverId, sharedLibraryId: null),
      [
        for (final p in pages)
          p.copyWith(
            id: privateCopyPageId(copyId, p.id),
            clearLibraryFileId: true,
          ),
      ],
      tagIds: tagIds,
      notify: false,
    );
  }

  /// Makes [documentId] the personal document of [diverId] under
  /// [detachedDocumentId], as its site leaves the library on this device,
  /// and removes the library rows.
  Future<String> keepAsPrivate(String documentId, String diverId) async {
    final document = await _documents.getById(documentId);
    final copyId = detachedDocumentId(documentId);
    if (document != null) {
      await _keepPrivateCopy(document, copyId, diverId);
    }
    await removeLibraryRows(documentId);
    return copyId;
  }

  /// Deletes the local rows of the library document [documentId] without a
  /// personal tombstone: it was never on the personal-sync wire.
  Future<void> removeLibraryRows(String documentId) async {
    await _db.transaction(() async {
      await (_db.delete(
        _db.documentTags,
      )..where((t) => t.documentId.equals(documentId))).go();
      await (_db.delete(
        _db.documentPages,
      )..where((t) => t.documentId.equals(documentId))).go();
      await (_db.delete(
        _db.documents,
      )..where((t) => t.id.equals(documentId))).go();
    });
  }
}
