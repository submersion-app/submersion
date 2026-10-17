import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:submersion/core/services/export/zip/zip_crypto_writer.dart';
import 'package:submersion/features/documents/data/repositories/document_repository.dart';
import 'package:submersion/features/documents/domain/document_archive_layout.dart';

/// Thrown by [DocumentArchiveExporter.write] when the user cancels.
class DocumentExportCancelled implements Exception {
  const DocumentExportCancelled();
}

/// Writes the documents export ZIP (#3397) to a file: `manifest.csv` first,
/// then every planned page, encrypted with ZipCrypto.
///
/// Pages are read one document at a time, and each entry is compressed and
/// encrypted on another isolate, so neither memory nor the UI isolate is
/// held by a large library. On cancel or failure the partial file is
/// deleted before the error propagates.
class DocumentArchiveExporter {
  DocumentArchiveExporter(this._repo);

  final DocumentRepository _repo;

  static const manifestName = 'manifest.csv';

  Future<void> write({
    required DocumentArchivePlan plan,
    required String manifestCsv,
    required String password,
    required String outputPath,
    required DateTime now,
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    final writer = await ZipCryptoWriter.open(outputPath, password: password);
    final total = plan.files.length + 1;
    var done = 0;
    Future<void> add(String name, Uint8List data) async {
      if (isCancelled?.call() ?? false) throw const DocumentExportCancelled();
      final entry = await _encode(
        writer.passwordBytes,
        data,
        writer.nextHeaderSeed(),
      );
      await writer.addEncoded(name, entry, modified: now);
      onProgress?.call(++done, total);
    }

    try {
      await add(manifestName, Uint8List.fromList(utf8.encode(manifestCsv)));
      // Files of one document are contiguous in the plan, so each
      // document's pages are read once and released before the next.
      String? loadedFor;
      var pages = const <String, Uint8List>{};
      for (final file in plan.files) {
        if (file.documentId != loadedFor) {
          pages = {
            for (final page in await _repo.getPages(file.documentId))
              page.id: page.bytes ?? Uint8List(0),
          };
          loadedFor = file.documentId;
        }
        final bytes = pages[file.pageId];
        if (bytes == null) {
          throw StateError('Page ${file.pageId} is no longer stored');
        }
        await add(file.path, bytes);
      }
      // A cancel pressed while the last file was written has no next entry
      // to be seen at, so it is checked once more before the archive is
      // finished and handed over.
      if (isCancelled?.call() ?? false) throw const DocumentExportCancelled();
      await writer.close();
    } catch (_) {
      try {
        await writer.abort();
      } on FileSystemException {
        // Already closed by a failing close(); the delete below still runs.
      }
      final partial = File(outputPath);
      if (partial.existsSync()) await partial.delete();
      rethrow;
    }
  }
}

// Top level, so the closure sent to the isolate captures only these
// arguments.
Future<EncodedZipEntry> _encode(
  Uint8List password,
  Uint8List data,
  Uint8List seed,
) => Isolate.run(() => encodeZipCryptoEntry(password, data, seed));
