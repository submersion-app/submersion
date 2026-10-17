import 'dart:io';

import 'package:path/path.dart' as p;

import 'package:submersion/core/services/logger_service.dart';
import 'package:submersion/features/documents/data/services/document_archive_exporter.dart';

final _log = LoggerService.forClass(DocumentArchiveExporter);

/// Name prefix of the folders exports are built in, under system temp.
const exportDirPrefix = 'submersion_documents_export_';

/// How long a shared archive is kept for its share target to read.
const _shareRetention = Duration(hours: 1);

/// A new folder for one export, named by its start time so two exports
/// never share one. A shared ZIP has to outlive the share call (AirDrop,
/// Mail and the Windows share targets read it afterwards), so it is left in
/// place and swept here, by a later export, once it is over an hour old.
Future<Directory> newDocumentExportDir(DateTime now) async {
  final temp = Directory.systemTemp;
  await for (final entry in temp.list()) {
    final name = p.basename(entry.path);
    if (entry is! Directory || !name.startsWith(exportDirPrefix)) continue;
    final started = int.tryParse(name.substring(exportDirPrefix.length));
    if (started == null) continue;
    final age = now.microsecondsSinceEpoch - started;
    if (age < _shareRetention.inMicroseconds) continue;
    try {
      await entry.delete(recursive: true);
    } on FileSystemException catch (e) {
      _log.warning('Could not remove an old export: $e');
    }
  }
  return Directory(
    p.join(temp.path, '$exportDirPrefix${now.microsecondsSinceEpoch}'),
  ).create();
}
