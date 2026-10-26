import 'package:csv/csv.dart';

import 'package:submersion/core/services/export/shared/export_file_name.dart';
import 'package:submersion/features/documents/domain/document_archive_layout.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// The localized words of the export manifest.
class ManifestLabels {
  /// The 15 column headers, in column order. Tags (issue #1970) comes last,
  /// so every earlier column keeps the position it always had.
  final List<String> headers;
  final String Function(DocumentType type) type;
  final String Function(DocumentOwnerKind kind) kind;
  final String front;
  final String back;

  const ManifestLabels({
    required this.headers,
    required this.type,
    required this.kind,
    required this.front,
    required this.back,
  });
}

/// UTF-8 byte order mark, so spreadsheet apps read accents correctly.
final _bom = String.fromCharCode(0xFEFF);

/// `manifest.csv` for the export ZIP (#3397): one row per file, plus one row
/// with no page or path for a document that has no file, so every
/// document's details survive outside the app.
String buildDocumentManifestCsv(
  List<ArchiveDocumentInput> docs,
  DocumentArchivePlan plan,
  ManifestLabels labels,
) {
  String date(DateTime? d) => d == null ? '' : fileNameDate(d);
  final rows = <List<String>>[labels.headers];
  for (final input in docs) {
    final d = input.document;
    final insurance = d.type == DocumentType.insurance;
    final details = [
      input.displayTitle,
      labels.type(d.type),
      labels.kind(d.owner.kind),
      input.recordFolder ?? '',
      d.issuer ?? '',
      d.referenceNumber ?? '',
      date(d.issueDate),
      date(d.expiryDate),
      d.notes,
      insurance ? d.emergencyPhone ?? '' : '',
      insurance ? d.phone ?? '' : '',
    ];
    final tags = input.tagNames.join('; ');
    final pages = [...input.pages]
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    if (pages.isEmpty) rows.add([...details, '', '', '', tags]);
    for (final (i, page) in pages.indexed) {
      rows.add([
        ...details,
        '${i + 1}',
        switch (page.side) {
          DocumentPageSide.front => labels.front,
          DocumentPageSide.back => labels.back,
          null => '',
        },
        plan.pathsByPageId[page.id] ?? '',
        tags,
      ]);
    }
  }
  return '$_bom${const ListToCsvConverter().convert(rows)}';
}
