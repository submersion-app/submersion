import 'dart:typed_data';

import 'package:submersion/features/universal_import/data/models/import_enums.dart';

/// One file a batch import's dives can be traced back to, keyed in the
/// importer by the collision-free `_sourceFileId` the payload merger stamps
/// on every item it merges (issue #478).
///
/// [readBytes] is invoked at most once per file, and only when a dive from
/// that file actually needs a stored copy, so a folder pick never holds every
/// raw buffer in memory at once.
class ImportSourceFile {
  const ImportSourceFile({
    required this.fileName,
    required this.format,
    required this.readBytes,
  });

  final String fileName;

  /// The format this file was parsed as, which is what a resync must pick its
  /// parser from. Per file: a batch can mix a CSV with a UDDF.
  final ImportFormat? format;

  final Future<Uint8List> Function() readBytes;
}
