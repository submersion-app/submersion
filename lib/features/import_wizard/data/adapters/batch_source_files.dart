import 'dart:io';

import 'package:submersion/features/dive_import/domain/import_source_file.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';

/// Per-file identity for an import run, keyed by the `_sourceFileId` the
/// payload merger stamps on every item it merges: `f<index>` into the picked
/// file list ([BatchParseService] assigns it from the same index).
///
/// The id, not the display name, is the key: two files picked from different
/// folders can share a basename, and attaching one file's stored copy to
/// another file's dives is worse than storing nothing.
///
/// Bytes are read only when a dive from that file needs a stored copy, and
/// only once per file -- batch files hold a path and no buffer precisely so a
/// folder pick never has every raw file in memory at once.
Map<String, ImportSourceFile> batchSourceFiles(List<PickedImportFile> files) {
  return {
    for (final (index, file) in files.indexed)
      'f$index': ImportSourceFile(
        fileName: file.name,
        format: file.detection.format,
        readBytes: () async {
          final bytes = file.bytes;
          if (bytes != null) return bytes;
          final path = file.path;
          if (path == null) {
            throw StateError('No bytes or path for ${file.name}');
          }
          return File(path).readAsBytes();
        },
      ),
  };
}
