import 'package:drift/drift.dart';
import 'package:uuid/uuid.dart';

import 'package:submersion/core/database/database.dart';
import 'package:submersion/core/services/database_service.dart';
import 'package:submersion/core/services/shared_library/crypto/canonical_json.dart';
import 'package:submersion/core/services/shared_library/library_document_record.dart';
import 'package:submersion/core/services/shared_library/shared_document_state.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/data/repositories/tag_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;

/// Turns a shared document's local rows into its library file and back
/// (issue #4713), the twin of `SiteDocumentBridge`. Writes here never stamp
/// a personal-sync clock: a library document travels only through its
/// library.
class LibraryDocumentBridge {
  LibraryDocumentBridge({TagRepository? tags})
    : _tags = tags ?? TagRepository();

  final TagRepository _tags;
  final _links = TagLinkRepository(domain.TagScope.documents);
  static const _uuid = Uuid();

  AppDatabase get _db => DatabaseService.instance.database;

  /// The record for the local document [documentId], from its row, pages
  /// and tags and the clocks in [state]. A page with no library file yet
  /// gets one, kept on its row so the next build names the same file.
  Future<LibraryDocumentRecord> build(
    String documentId,
    SharedDocumentState state,
  ) async {
    final row = await (_db.select(
      _db.documents,
    )..where((t) => t.id.equals(documentId))).getSingleOrNull();
    if (row == null) {
      throw StateError('document $documentId has no row to build from');
    }
    final pages =
        await (_db.select(_db.documentPages)
              ..where((t) => t.documentId.equals(documentId))
              ..orderBy([(t) => OrderingTerm(expression: t.pageIndex)]))
            .get();
    final refs = <Map<String, Object?>>[];
    for (final p in pages) {
      var fileId = p.libraryFileId;
      if (fileId == null) {
        fileId = _uuid.v4();
        await (_db.update(_db.documentPages)..where((t) => t.id.equals(p.id)))
            .write(DocumentPagesCompanion(libraryFileId: Value(fileId)));
      }
      refs.add(
        LibraryPageRef(
          id: p.id,
          pageIndex: p.pageIndex,
          side: p.side,
          fileName: p.fileName,
          mimeType: p.mimeType,
          sizeBytes: p.bytes.length,
          fileId: fileId,
          sha256: sha256Hex(p.bytes),
        ).toJson(),
      );
    }
    final tags = await _links.getTagsFor(documentId);
    return LibraryDocumentRecord(
      id: documentId,
      siteId: state.siteId,
      deleted: state.deleted,
      fields: {
        'type': row.type,
        'title': row.title,
        'issuer': row.issuer,
        'referenceNumber': row.referenceNumber,
        'issueDate': row.issueDate,
        'expiryDate': row.expiryDate,
        'notes': row.notes,
        'tags': [for (final t in tags) t.name],
        'pages': refs,
      },
      clocks: Map.of(state.clocks),
    );
  }

  /// Whether [doc] may be written here for [libraryId]: a new id, a row of
  /// this library, or the diver's own document filed on a site of it (its
  /// share arriving from another device). Never a row of another library,
  /// a private copy filed elsewhere, or a page of another document: a
  /// record of one library must not take over what is not its own.
  Future<bool> mayAdopt(LibraryDocumentRecord doc, String libraryId) async {
    final row = await (_db.select(
      _db.documents,
    )..where((t) => t.id.equals(doc.id))).getSingleOrNull();
    if (row != null) {
      final owner = row.sharedLibraryId;
      if (owner != null && owner != libraryId) return false;
      if (owner == null) {
        final siteId = row.siteId;
        if (siteId == null) return false;
        final site = await (_db.select(
          _db.diveSites,
        )..where((t) => t.id.equals(siteId))).getSingleOrNull();
        if (site?.sharedLibraryId != libraryId) return false;
      }
    }
    final pageIds = [for (final r in doc.pageRefs) r.id];
    if (pageIds.isEmpty) return true;
    final clash =
        await (_db.select(_db.documentPages)..where(
              (t) => t.id.isIn(pageIds) & t.documentId.equals(doc.id).not(),
            ))
            .get();
    return clash.isEmpty;
  }

  /// The library files whose bytes [documentId]'s pages already hold.
  Future<Set<String>> heldFileIds(String documentId) async {
    final t = _db.documentPages;
    final rows =
        await (_db.selectOnly(t)
              ..addColumns([t.libraryFileId])
              ..where(t.documentId.equals(documentId)))
            .get();
    return {for (final r in rows) ?r.read(t.libraryFileId)};
  }

  /// Writes [fields] of [doc] (all of them when null) to the local library
  /// row, creating it filed under its site with no diver. A page is taken
  /// from [pageBytesByFileId], or kept from a local page already holding
  /// its file; one with neither throws, so a half-fetched document is never
  /// written. Tags resolve by name against [vocabularyDiverId]'s tags,
  /// created when missing.
  Future<void> apply(
    LibraryDocumentRecord doc, {
    required String libraryId,
    required String vocabularyDiverId,
    required Map<String, Uint8List> pageBytesByFileId,
    Set<String>? fields,
  }) async {
    final exists =
        await (_db.select(
          _db.documents,
        )..where((t) => t.id.equals(doc.id))).getSingleOrNull() !=
        null;
    // A new row takes every field the record has.
    final names = (exists ? fields ?? doc.fields.keys.toSet() : doc.fields.keys)
        .where(doc.fields.containsKey)
        .toSet();
    final now = DateTime.now().millisecondsSinceEpoch;
    final pageRefs = names.contains('pages') ? doc.pageRefs : null;
    final pageBytes = pageRefs == null
        ? const <String, Uint8List>{}
        : await _bytesFor(doc.id, libraryId, pageRefs, pageBytesByFileId);
    await _db.transaction(() async {
      final row = _scalarsOf(doc, names).copyWith(
        id: Value(doc.id),
        diverId: const Value(null),
        sharedLibraryId: Value(libraryId),
        siteId: Value(doc.siteId),
        diveId: const Value(null),
        tripId: const Value(null),
        equipmentId: const Value(null),
        courseId: const Value(null),
        certificationId: const Value(null),
        buddyId: const Value(null),
        diveCenterId: const Value(null),
        isPrimary: const Value(false),
        emergencyPhone: const Value(null),
        phone: const Value(null),
        createdAt: exists ? const Value.absent() : Value(now),
        updatedAt: Value(now),
      );
      if (exists) {
        await (_db.update(
          _db.documents,
        )..where((t) => t.id.equals(doc.id))).write(row);
      } else {
        await _db.into(_db.documents).insert(row);
      }
      if (pageRefs != null) {
        await _replacePages(doc.id, pageRefs, pageBytes, now);
      }
    });
    if (names.contains('tags')) {
      await _applyTags(doc.id, doc.fields['tags'], vocabularyDiverId);
    }
  }

  /// The `documents` columns of [names] from [doc]; a value of the wrong
  /// shape reads as empty, as an absent one would.
  static DocumentsCompanion _scalarsOf(
    LibraryDocumentRecord doc,
    Set<String> names,
  ) {
    Value<T> pick<T>(String name, T Function(Object? raw) read) =>
        names.contains(name)
        ? Value(read(doc.fields[name]))
        : const Value.absent();
    String? text(Object? v) => v is String ? v : null;
    int? ms(Object? v) => v is int ? v : null;
    return DocumentsCompanion(
      type: pick('type', (v) => DocumentType.fromStorage(text(v)).storage),
      title: pick('title', (v) => text(v) ?? ''),
      issuer: pick('issuer', text),
      referenceNumber: pick('referenceNumber', text),
      issueDate: pick('issueDate', ms),
      expiryDate: pick('expiryDate', ms),
      notes: pick('notes', (v) => text(v) ?? ''),
    );
  }

  Future<Map<String, Uint8List>> _bytesFor(
    String documentId,
    String libraryId,
    List<LibraryPageRef> refs,
    Map<String, Uint8List> incoming,
  ) async {
    final out = <String, Uint8List>{};
    for (final ref in refs) {
      final bytes =
          incoming[ref.fileId] ??
          await heldPageBytes(ref.fileId, libraryId: libraryId);
      if (bytes == null) {
        throw StateError('page file ${ref.fileId} of $documentId not held');
      }
      out[ref.fileId] = bytes;
    }
    return out;
  }

  /// The bytes of library file [fileId] as a local page of a [libraryId]
  /// document holds them, or null. Never another library's: a record of one
  /// library naming another's file id must not take, or later upload, that
  /// library's page.
  Future<Uint8List?> heldPageBytes(
    String fileId, {
    required String libraryId,
  }) async {
    final rows = await _db
        .customSelect(
          'SELECT p.bytes AS b FROM document_pages p '
          'JOIN documents d ON d.id = p.document_id '
          'WHERE p.library_file_id = ? AND d.shared_library_id = ? LIMIT 1',
          variables: [
            Variable.withString(fileId),
            Variable.withString(libraryId),
          ],
          readsFrom: {_db.documentPages, _db.documents},
        )
        .get();
    return rows.firstOrNull?.read<Uint8List>('b');
  }

  /// Every library file whose bytes a local page of a shared document holds
  /// (of [libraryId] only, when given).
  Future<Set<String>> heldPageFileIds({String? libraryId}) async {
    final rows = await _db
        .customSelect(
          'SELECT p.library_file_id AS f FROM document_pages p '
          'JOIN documents d ON d.id = p.document_id '
          'WHERE p.library_file_id IS NOT NULL '
          'AND d.shared_library_id IS NOT NULL'
          '${libraryId == null ? '' : ' AND d.shared_library_id = ?'}',
          variables: [if (libraryId != null) Variable.withString(libraryId)],
          readsFrom: {_db.documentPages, _db.documents},
        )
        .get();
    return {for (final r in rows) r.read<String>('f')};
  }

  Future<void> _replacePages(
    String documentId,
    List<LibraryPageRef> refs,
    Map<String, Uint8List> bytes,
    int now,
  ) async {
    final ids = {for (final r in refs) r.id};
    await (_db.delete(
      _db.documentPages,
    )..where((t) => t.documentId.equals(documentId) & t.id.isNotIn(ids))).go();
    for (final ref in refs) {
      final content = bytes[ref.fileId]!;
      await _db
          .into(_db.documentPages)
          .insertOnConflictUpdate(
            DocumentPagesCompanion.insert(
              id: ref.id,
              documentId: documentId,
              pageIndex: ref.pageIndex,
              side: Value(ref.side),
              fileName: ref.fileName,
              mimeType: ref.mimeType,
              sizeBytes: content.length,
              bytes: content,
              createdAt: now,
              updatedAt: now,
              libraryFileId: Value(ref.fileId),
            ),
          );
    }
  }

  Future<void> _applyTags(
    String documentId,
    Object? raw,
    String diverId,
  ) async {
    final names = [
      if (raw is List)
        for (final n in raw)
          if (n is String && n.trim().isNotEmpty) n.trim(),
    ];
    final known = await _tags.getAllTags(diverId: diverId);
    final byName = {for (final t in known) t.name.toLowerCase(): t.id};
    final ids = <String>[];
    for (final name in names) {
      var id = byName[name.toLowerCase()];
      if (id == null) {
        final now = DateTime.now();
        final created = await _tags.createTag(
          domain.Tag(
            id: '',
            diverId: diverId,
            name: name,
            createdAt: now,
            updatedAt: now,
            scopes: domain.TagScope.everywhere,
          ),
          widenExistingTo: const {domain.TagScope.documents},
        );
        id = created.id;
        byName[name.toLowerCase()] = id;
      }
      if (!ids.contains(id)) ids.add(id);
    }
    await _links.replaceTags(documentId, ids, notify: false);
  }
}
