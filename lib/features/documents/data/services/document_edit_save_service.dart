import 'package:submersion/core/providers/provider.dart';
import 'package:submersion/core/services/change_log/record_sitting_writer.dart';
import 'package:submersion/core/services/logger_service.dart';
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
  DocumentEditSaveService(this._documents, this._tags);

  final DocumentRepository _documents;
  final TagLinkRepository _tags;

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
