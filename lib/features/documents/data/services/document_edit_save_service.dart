import 'package:flutter/foundation.dart';

import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/core/services/shared_library/library_document_stamper.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/presentation/editing/document_edit_fields.dart';
import 'package:submersion/features/documents/presentation/editing/document_record.dart';
import 'package:submersion/features/documents/presentation/providers/document_providers.dart';
import 'package:submersion/features/tags/data/repositories/tag_link_repository.dart';
import 'package:submersion/features/tags/domain/entities/tag.dart' as domain;
import 'package:submersion/features/tags/presentation/providers/tag_link_providers.dart';

const _log = LoggerService('DocumentEditSaveService');

/// Reads and writes a document page's editing sitting (issue #4527, phase
/// 3): the row, its pages and its tags, in one transaction and one History
/// entry labelled with the cards it changed.
class DocumentEditSaveService {
  DocumentEditSaveService(
    this._documents,
    this._tags, {
    LibraryDocumentStamper? library,
  }) : _library = library ?? LibraryDocumentStamper(documents: _documents);

  final DocumentRepository _documents;
  final TagLinkRepository _tags;

  /// Stamps edits to a document shared with a shared site library, and
  /// shares a new one there by default (issue #4713). Both run after the
  /// sitting commits: a rolled-back sitting must not leave a clock behind.
  final LibraryDocumentStamper _library;

  /// Document [id] as stored: its row, its pages without their content,
  /// and its tags (null when they cannot be read). Null when it is gone.
  Future<DocumentRecord?> read(String id) async {
    final document = await _documents.getById(id);
    if (document == null) return null;
    final pages = await _documents.getPages(id, withBytes: false);
    List<String>? tagIds;
    try {
      tagIds = [for (final tag in await _tags.getTagsFor(id)) tag.id];
    } catch (error, stackTrace) {
      _log.warning(
        'Could not read the tags of document $id',
        error: error,
        stackTrace: stackTrace,
      );
    }
    return DocumentRecord(document: document, pages: pages, tagIds: tagIds);
  }

  /// Watches what [read] reads.
  Stream<void> watchChanges() => _documents.watchChanges();

  /// The tags' own changes, which [watchChanges] does not see.
  Stream<void> watchTagChanges() => _tags.watchChanges();

  /// Saves [apply] onto document [documentId] as stored now, so a value
  /// changed underneath on a card the diver never touched is kept. The tags
  /// are written only when the sitting changed them, and never when they
  /// could not be read. Returns the record before and after, or null when
  /// nothing changed. Throws [StateError] when the document no longer
  /// exists.
  Future<({DocumentRecord before, DocumentRecord after})?> save({
    required String documentId,
    required DocumentRecord Function(DocumentRecord stored) apply,
    required Iterable<String> changedCardIds,
    String? actingDiverId,
  }) async {
    // A shared library document only its editors and owners change, here as
    // in the screens (issue #4713).
    if (!await _library.mayEdit(documentId, actingDiverId: actingDiverId)) {
      throw StateError('document $documentId is read only in its library');
    }
    final saved = await _writeSitting(
      documentId: documentId,
      apply: apply,
      changedCardIds: changedCardIds,
    );
    if (saved != null && saved.after.document.isShared) {
      await _library.stamp(
        documentId,
        libraryFieldsChanged(saved.before, saved.after),
        actingDiverId: actingDiverId,
        authorized: true,
      );
    }
    return saved;
  }

  /// The library document fields [after] changed from [before].
  @visibleForTesting
  static Set<String> libraryFieldsChanged(
    DocumentRecord before,
    DocumentRecord after,
  ) {
    final a = before.document;
    final b = after.document;
    final pagesChanged =
        !listEquals(before.pages, after.pages) ||
        after.pages.any((p) => p.bytes != null);
    return {
      if (a.type != b.type) 'type',
      if (a.title != b.title) 'title',
      if (a.issuer != b.issuer) 'issuer',
      if (a.referenceNumber != b.referenceNumber) 'referenceNumber',
      if (a.issueDate != b.issueDate) 'issueDate',
      if (a.expiryDate != b.expiryDate) 'expiryDate',
      if (a.notes != b.notes) 'notes',
      if (after.tagIds != null &&
          !DocumentRecord.sameTags(before.tagIds, after.tagIds))
        'tags',
      if (pagesChanged) 'pages',
    };
  }

  Future<({DocumentRecord before, DocumentRecord after})?> _writeSitting({
    required String documentId,
    required DocumentRecord Function(DocumentRecord stored) apply,
    required Iterable<String> changedCardIds,
  }) => writeRecordSitting<DocumentRecord>(
    table: 'documents',
    recordId: documentId,
    changedCardIds: changedCardIds,
    read: () => read(documentId),
    apply: apply,
    write: (stored, merged) async {
      final tags = merged.tagIds;
      final tagsChanged =
          tags != null && !DocumentRecord.sameTags(tags, stored.tagIds);
      await _documents.save(
        documentAsSaved(merged.document),
        merged.pages,
        tagIds: tagsChanged ? tags : null,
        // The sitting tells sync once, after its commit.
        notify: false,
      );
    },
  );

  /// Creates [record], a new document's sitting (issue #4527, phase 3, plan
  /// 11), keeping its id: the row, its pages and its tags, then
  /// [alsoWrite], the sitting's held writes, in one transaction and one
  /// History entry naming [changedCardIds]. If any of them throws nothing
  /// is left. Returns the document as stored at the end. Throws
  /// [StateError] when [record] has no id, or one a stored document has.
  Future<DocumentRecord> create({
    required DocumentRecord record,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) async {
    final created = await _createSitting(
      record: record,
      changedCardIds: changedCardIds,
      alsoWrite: alsoWrite,
    );
    final diverId = record.document.diverId;
    if (diverId == null) return created;
    // A new document on a library site starts shared, unless its type is a
    // diver's own papers or the diver only reads the library (issue #4713).
    if (await _library.shareIfDefault(record.id, actingDiverId: diverId)) {
      return await read(record.id) ?? created;
    }
    return created;
  }

  Future<DocumentRecord> _createSitting({
    required DocumentRecord record,
    required Iterable<String> changedCardIds,
    Future<void> Function()? alsoWrite,
  }) => createRecordSitting<DocumentRecord>(
    table: 'documents',
    recordId: record.id,
    changedCardIds: changedCardIds,
    isStored: () async => await _documents.getById(record.id) != null,
    insert: () => _documents.save(
      documentAsSaved(record.document),
      record.pages,
      tagIds: record.tagIds,
      // The sitting tells sync once, after its commit.
      notify: false,
    ),
    alsoWrite: alsoWrite,
    readBack: () => read(record.id),
    created: record,
  );
}

final documentEditSaveServiceProvider = Provider<DocumentEditSaveService>(
  (ref) => DocumentEditSaveService(
    ref.watch(documentRepositoryProvider),
    ref.watch(tagLinkRepositoryProvider(domain.TagScope.documents)),
  ),
);
