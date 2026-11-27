import 'package:submersion/core/database/database.dart';

/// Documents shared with a shared site library (issue #4713) belong to the
/// library: they, their pages and their tag links stay out of the personal
/// sync in both directions, as library sites do.

/// The personal-sync entities that are children of a document.
const Set<String> libraryDocumentChildEntities = {
  'documentPages',
  'documentTags',
};

/// Ids of the documents this device holds for a shared site library.
Future<Set<String>> libraryDocumentIds(AppDatabase db) async {
  final rows =
      await (db.selectOnly(db.documents)
            ..addColumns([db.documents.id])
            ..where(db.documents.sharedLibraryId.isNotNull()))
          .get();
  return {for (final r in rows) r.read(db.documents.id)!};
}

/// Whether the personal-sync row [row] of [entityType] belongs to one of
/// the library documents [libraryDocuments].
bool isLibraryDocumentRow(
  String entityType,
  Map<String, dynamic> row,
  Set<String> libraryDocuments,
) {
  if (libraryDocuments.isEmpty) return false;
  if (entityType == 'documents') {
    return row['sharedLibraryId'] != null ||
        libraryDocuments.contains(row['id']);
  }
  if (libraryDocumentChildEntities.contains(entityType)) {
    return libraryDocuments.contains(row['documentId']);
  }
  return false;
}

/// [rows] without those of library documents.
List<Map<String, dynamic>> withoutLibraryDocumentRows(
  String entityType,
  List<Map<String, dynamic>> rows,
  Set<String> libraryDocuments,
) => libraryDocuments.isEmpty
    ? rows
    : [
        for (final row in rows)
          if (!isLibraryDocumentRow(entityType, row, libraryDocuments)) row,
      ];
