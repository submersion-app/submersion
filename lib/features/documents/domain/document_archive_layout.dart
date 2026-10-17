import 'package:path/path.dart' as p;

import 'package:submersion/core/services/export/shared/export_file_name.dart';
import 'package:submersion/features/documents/domain/entities/document.dart';
import 'package:submersion/features/documents/domain/entities/document_page.dart';

/// One document going into the export ZIP (#3397), with its names already
/// resolved by the caller.
class ArchiveDocumentInput {
  final Document document;

  /// The title as the app shows it (the type's name when the title is empty).
  final String displayTitle;

  /// The top-level folder: the localized owner kind (`Dives`, `Personal`).
  final String kindFolder;

  /// The record folder inside [kindFolder]; null puts the document directly
  /// in [kindFolder] (personal documents).
  final String? recordFolder;

  /// Page metadata in any order; bytes are not needed here.
  final List<DocumentPage> pages;

  const ArchiveDocumentInput({
    required this.document,
    required this.displayTitle,
    required this.kindFolder,
    required this.recordFolder,
    required this.pages,
  });
}

/// The localized words the layout puts in file names.
class ArchiveNames {
  final String front;
  final String back;
  final String Function(int n) page;

  const ArchiveNames({
    required this.front,
    required this.back,
    required this.page,
  });
}

/// One file in the ZIP and the page it comes from.
class ArchiveFileEntry {
  final String path;
  final String documentId;
  final String pageId;

  const ArchiveFileEntry({
    required this.path,
    required this.documentId,
    required this.pageId,
  });
}

class DocumentArchivePlan {
  final List<ArchiveFileEntry> files;

  /// Page id to its path in the ZIP, for the manifest.
  final Map<String, String> pathsByPageId;

  const DocumentArchivePlan({required this.files, required this.pathsByPageId});
}

final _invalid = RegExp(r'[<>:"/\\|?*\x00-\x1f\x7f]');
final _trailingDotsAndSpaces = RegExp(r'[. ]+$');

/// [raw] made safe as one path segment on Windows, macOS and Linux: invalid
/// characters become `_`, outer spaces and trailing dots go, the name is cut
/// to [fileNameSegmentMaxBytes] UTF-8 bytes (file systems cap a name at 255
/// bytes, and a suffix and extension still follow), Windows device names
/// get a `_`, and the result is never empty.
String sanitizeArchiveSegment(String raw) {
  var s = raw.replaceAll(_invalid, '_').trim();
  s = truncateUtf8(s, fileNameSegmentMaxBytes);
  s = s.replaceFirst(_trailingDotsAndSpaces, '');
  if (s.isEmpty) return '_';
  final stem = s.split('.').first;
  if (isWindowsReservedName(stem)) {
    return '${stem}_${s.substring(stem.length)}';
  }
  return s;
}

const _extensionsByMime = {
  'image/jpeg': '.jpg',
  'image/png': '.png',
  'image/heic': '.heic',
  'image/heif': '.heif',
  'image/webp': '.webp',
  'image/gif': '.gif',
  'image/tiff': '.tiff',
  'application/pdf': '.pdf',
  'text/plain': '.txt',
  'application/msword': '.doc',
  'application/vnd.openxmlformats-officedocument.wordprocessingml.document':
      '.docx',
};

final _plainExtension = RegExp(r'^\.[A-Za-z0-9]{1,10}$');

/// The extension a page's file gets: its stored name's, else one for its
/// MIME type, else `.bin`.
String archiveExtension(DocumentPage page) {
  final stored = p.extension(page.fileName);
  if (_plainExtension.hasMatch(stored)) return stored;
  return _extensionsByMime[page.mimeType] ?? '.bin';
}

/// Where each page of [docs] goes in the export ZIP, as
/// `<kind>/<record>/<title>[ - front| - back| - page n].<ext>`, with `(2)`,
/// `(3)` added when a name repeats in a folder (compared ignoring case, so
/// a case-insensitive file system never overwrites one file with another).
DocumentArchivePlan planDocumentArchive(
  List<ArchiveDocumentInput> docs,
  ArchiveNames names,
) {
  final files = <ArchiveFileEntry>[];
  final paths = <String, String>{};
  final used = <String>{};
  for (final doc in docs) {
    final folder = [
      sanitizeArchiveSegment(doc.kindFolder),
      if (doc.recordFolder case final record?) sanitizeArchiveSegment(record),
    ].join('/');
    final title = sanitizeArchiveSegment(doc.displayTitle);
    final pages = [...doc.pages]
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    for (final (i, page) in pages.indexed) {
      final suffix = switch (page.side) {
        DocumentPageSide.front => ' - ${names.front}',
        DocumentPageSide.back => ' - ${names.back}',
        null when pages.length > 1 => ' - ${names.page(i + 1)}',
        null => '',
      };
      final ext = archiveExtension(page);
      var path = '$folder/$title$suffix$ext';
      for (var n = 2; used.contains(path.toLowerCase()); n++) {
        path = '$folder/$title$suffix ($n)$ext';
      }
      used.add(path.toLowerCase());
      paths[page.id] = path;
      files.add(
        ArchiveFileEntry(
          path: path,
          documentId: doc.document.id,
          pageId: page.id,
        ),
      );
    }
  }
  return DocumentArchivePlan(files: files, pathsByPageId: paths);
}
