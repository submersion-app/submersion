import 'dart:io';

import 'package:submersion/features/import_wizard/domain/models/import_source_details.dart';
import 'package:submersion/features/universal_import/data/models/import_enums.dart';
import 'package:submersion/features/universal_import/data/models/import_options.dart';
import 'package:submersion/features/universal_import/data/models/picked_import_file.dart';

/// What the Review step shows about a file import (issue #161): the picked
/// file, or how many files a batch imported, with the formats and app
/// detection found and their total size.
///
/// A batch counts only the files it parsed: one that failed, was set aside as
/// CSV or is unsupported put no dives on the Review step. A single file
/// reports the format and app the diver [confirmed], which may override what
/// detection guessed.
Future<ImportSourceDetails> fileSourceDetails(
  List<PickedImportFile> picked, {
  ImportOptions? confirmed,
}) async {
  final files = picked.length > 1
      ? [
          for (final file in picked)
            if (file.status == ImportFileStatus.parsed) file,
        ]
      : picked;
  if (files.isEmpty) return const ImportSourceDetails();

  final options = picked.length == 1 ? confirmed : null;
  final formats = {
    if (options != null)
      options.format.displayName
    else
      for (final file in files) file.detection.format.displayName,
  };
  final apps = {
    if (options != null)
      options.sourceApp
    else
      for (final file in files) file.detection.sourceApp,
  };
  final app = apps.length == 1 ? apps.single : null;

  return ImportSourceDetails(
    title: files.length == 1 ? files.single.name : null,
    fileCount: files.length,
    formats: formats.toList(),
    sourceApp: app == null || app == SourceApp.generic ? null : app.displayName,
    sizeBytes: await _totalSize(files),
  );
}

/// The combined size of [files], or null when any of them cannot be read:
/// a partial total would understate what is being imported.
Future<int?> _totalSize(List<PickedImportFile> files) async {
  final sizes = await Future.wait(files.map(_size));
  return sizes.contains(null)
      ? null
      : sizes.fold<int>(0, (total, size) => total + size!);
}

Future<int?> _size(PickedImportFile file) async {
  final bytes = file.bytes;
  if (bytes != null) return bytes.length;
  final path = file.path;
  if (path == null) return null;
  try {
    return await File(path).length();
  } on FileSystemException {
    return null;
  }
}
