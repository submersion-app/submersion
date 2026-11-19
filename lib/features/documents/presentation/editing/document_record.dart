import 'package:flutter/foundation.dart';

import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// What a document page's sitting edits (issue #4527, phase 3): the
/// document's row, its pages and its tags, which
/// `DocumentRepository.save` writes together in one transaction.
@immutable
class DocumentRecord {
  const DocumentRecord({
    required this.document,
    required this.pages,
    required this.tagIds,
  });

  final Document document;

  /// Its pages, read without their content: a page with no bytes keeps
  /// what is stored when written back.
  final List<DocumentPage> pages;

  /// Its tags' ids; null when they could not be read, so they are neither
  /// offered for editing nor written.
  final List<String>? tagIds;

  String get id => document.id;

  DocumentRecord copyWith({
    Document? document,
    List<DocumentPage>? pages,
    List<String>? tagIds,
    bool clearTags = false,
  }) => DocumentRecord(
    document: document ?? this.document,
    pages: pages ?? this.pages,
    tagIds: clearTags ? null : tagIds ?? this.tagIds,
  );

  /// Whether [a] and [b] are the same tags, in any order.
  static bool sameTags(List<String>? a, List<String>? b) =>
      a == null || b == null ? a == b : setEquals(a.toSet(), b.toSet());

  @override
  bool operator ==(Object other) =>
      other is DocumentRecord &&
      other.document == document &&
      listEquals(other.pages, pages) &&
      sameTags(other.tagIds, tagIds);

  @override
  int get hashCode => Object.hash(
    document,
    Object.hashAll(pages),
    tagIds == null ? null : Object.hashAllUnordered(tagIds!),
  );
}
