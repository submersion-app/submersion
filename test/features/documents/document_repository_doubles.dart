import 'dart:typed_data';

import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// The real repository, recording what is read of a document's pages.
class DocumentReadSpy extends DocumentRepository {
  DocumentReadSpy() : super(cancelReminders: (_) async {});

  final contentReads = <String>[];
  final pageListings = <bool>[];

  @override
  Future<List<DocumentPage>> getPages(
    String documentId, {
    bool withBytes = true,
  }) {
    pageListings.add(withBytes);
    return super.getPages(documentId, withBytes: withBytes);
  }

  @override
  Future<Uint8List?> getPageContent(String pageId) {
    contentReads.add(pageId);
    return super.getPageContent(pageId);
  }
}

/// Serves page content from memory, without a database, and records reads.
class FakeDocumentContent extends DocumentRepository {
  FakeDocumentContent({this.failing = false})
    : super(cancelReminders: (_) async {});

  final bool failing;
  final reads = <String>[];

  @override
  Future<Uint8List?> getPageContent(String pageId) async {
    reads.add(pageId);
    if (failing) throw StateError('read failed');
    return Uint8List.fromList([0, 1]);
  }
}
